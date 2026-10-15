package com.ironpeak.ironpeak_mobile

import android.content.ComponentName
import android.content.Intent
import android.content.IntentSender
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The app's only activity. Release builds never list it in the launcher
 * directly: every home-screen icon is an `<activity-alias>` targeting it
 * (src/release/AndroidManifest.xml, generated from
 * lib/theme/launcher_icons.dart), exactly one of them enabled, and switching
 * the icon means enabling another alias and disabling the old one.
 * Debug/profile builds declare no aliases, so the channel below reports
 * `supported = false` there and `flutter run` keeps launching this activity.
 *
 * Disabling the alias a task was launched from makes Android remove that
 * task -- the app would close under the user's finger. So Dart
 * (lib/services/launcher_icon_service.dart) only names the icon it wants,
 * and the switch happens here once the user has deliberately left the app.
 */
class IronpeakActivity : FlutterActivity() {
    /** Every alias Dart knows about, relative (".LauncherIcon_dark_teal"). */
    private var aliases: List<String> = emptyList()

    /** The alias to switch to once the user leaves; null keeps the icon as it is. */
    private var pendingAlias: String? = null

    // Both reset in onResume. onUserLeaveHint alone can't tell a real exit
    // apart: Android also calls it when this activity starts another one (a
    // file or photo picker, the share sheet, the browser, Health Connect, the
    // APK installer), and switching then would remove the very task -- and
    // the pending result -- the user is about to come back to.
    private var userLeft = false
    private var launchedOwnActivity = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::onLauncherIconCall)
    }

    override fun onResume() {
        super.onResume()
        userLeft = false
        launchedOwnActivity = false
    }

    // Home, the app switcher, opening another app's notification: the user
    // chose to leave. Not called for screen-off or an incoming call, after
    // which the app must still be there.
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        userLeft = true
    }

    // Activity.startActivity(...) always ends up in this overload.
    override fun startActivityForResult(intent: Intent, requestCode: Int, options: Bundle?) {
        launchedOwnActivity = true
        try {
            super.startActivityForResult(intent, requestCode, options)
        } catch (e: RuntimeException) {
            // Nothing started (no app for the intent, ...): this activity
            // stays resumed, so the next exit is a real one again.
            launchedOwnActivity = false
            throw e
        }
    }

    // The 6-argument overload and startIntentSender(...) delegate to this one.
    override fun startIntentSenderForResult(
        intent: IntentSender,
        requestCode: Int,
        fillInIntent: Intent?,
        flagsMask: Int,
        flagsValues: Int,
        extraFlags: Int,
        options: Bundle?,
    ) {
        launchedOwnActivity = true
        try {
            super.startIntentSenderForResult(
                intent, requestCode, fillInIntent, flagsMask, flagsValues, extraFlags, options,
            )
        } catch (e: Exception) {
            launchedOwnActivity = false
            throw e
        }
    }

    override fun onStop() {
        super.onStop()
        val target = pendingAlias ?: return
        // isFinishing covers Back out of the first screen up to Android 15
        // (FlutterActivity finishes then), which is just as deliberate an
        // exit. Android 16's predictive Back only moves the task to the back
        // without either signal; the switch then waits for the next Home.
        if ((userLeft || isFinishing) && !launchedOwnActivity && !isChangingConfigurations) {
            switchTo(target)
        }
    }

    private fun onLauncherIconCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            call.argument<List<*>>("aliases")?.filterIsInstance<String>()?.let {
                if (it.isNotEmpty()) aliases = it
            }
            when (call.method) {
                "getState" -> result.success(
                    mapOf(
                        "supported" to aliases.any { aliasEnabled(it) != null },
                        "enabled" to enabledAliases(),
                    ),
                )
                "enableNow" -> result.success(enableNow(call.argument<String>("target")))
                "setTarget" -> {
                    setTarget(call.argument<String>("target"))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.w(TAG, "${call.method} failed", e)
            result.error("launcher_icon", e.message, null)
        }
    }

    /**
     * Repairs a phone left without any launcher entry for the app: enables
     * [target] right away and disables nothing, which is safe while the app
     * is in the foreground. Does nothing while any alias is still enabled.
     */
    private fun enableNow(target: String?): Boolean {
        if (target == null || target !in aliases || aliasEnabled(target) == null) return false
        if (enabledAliases().isNotEmpty()) return false
        packageManager.setComponentEnabledSetting(
            componentFor(target),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        return true
    }

    private fun setTarget(target: String?) {
        pendingAlias = when {
            target == null -> null
            target !in aliases -> {
                Log.w(TAG, "Ignoring unknown launcher alias $target")
                null
            }
            enabledAliases() == listOf(target) -> null
            else -> target
        }
    }

    /**
     * Enables [target] first and only then disables every other alias that
     * is still enabled, so a failure half-way leaves two launcher entries,
     * never none. DONT_KILL_APP keeps the process alive; the task launched
     * from the old alias goes away regardless, hence only after the user left.
     */
    private fun switchTo(target: String) {
        if (target !in aliases || aliasEnabled(target) == null) {
            pendingAlias = null
            return
        }
        val others = aliases.filter { it != target && aliasEnabled(it) == true }
        if (others.isEmpty() && aliasEnabled(target) == true) {
            pendingAlias = null
            return
        }
        val changes = listOf(target to PackageManager.COMPONENT_ENABLED_STATE_ENABLED) +
            others.map { it to PackageManager.COMPONENT_ENABLED_STATE_DISABLED }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // One transaction and one PACKAGE_CHANGED broadcast, so the
                // launcher never sees an in-between state.
                packageManager.setComponentEnabledSettings(
                    changes.map { (alias, state) ->
                        PackageManager.ComponentEnabledSetting(
                            componentFor(alias), state, PackageManager.DONT_KILL_APP,
                        )
                    },
                )
            } else {
                for ((alias, state) in changes) {
                    packageManager.setComponentEnabledSetting(
                        componentFor(alias), state, PackageManager.DONT_KILL_APP,
                    )
                }
            }
            pendingAlias = null
        } catch (e: Exception) {
            // pendingAlias stays, so the next exit tries again.
            Log.w(TAG, "Switching the launcher icon to $target failed", e)
            ensureLauncherEntry(target)
        }
    }

    private fun ensureLauncherEntry(fallback: String) {
        try {
            if (enabledAliases().isEmpty()) {
                packageManager.setComponentEnabledSetting(
                    componentFor(fallback),
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP,
                )
            }
        } catch (e: Exception) {
            Log.w(TAG, "Restoring a launcher entry failed", e)
        }
    }

    private fun enabledAliases(): List<String> = aliases.filter { aliasEnabled(it) == true }

    /**
     * Whether [alias] is effectively enabled right now, or null when this
     * build doesn't declare it (debug/profile builds declare none).
     */
    private fun aliasEnabled(alias: String): Boolean? {
        val component = componentFor(alias)
        return try {
            val info = activityInfo(component)
            when (packageManager.getComponentEnabledSetting(component)) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
                // Never changed at runtime: the manifest's android:enabled.
                PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> info.enabled
                // DISABLED, DISABLED_USER, DISABLED_UNTIL_USED.
                else -> false
            }
        } catch (e: PackageManager.NameNotFoundException) {
            null
        } catch (e: IllegalArgumentException) {
            // getComponentEnabledSetting's "unknown component".
            null
        }
    }

    private fun activityInfo(component: ComponentName): ActivityInfo =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getActivityInfo(
                component,
                PackageManager.ComponentInfoFlags.of(PackageManager.MATCH_DISABLED_COMPONENTS.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getActivityInfo(component, PackageManager.MATCH_DISABLED_COMPONENTS)
        }

    private fun componentFor(alias: String) =
        ComponentName(packageName, if (alias.startsWith('.')) NAMESPACE + alias else alias)

    private companion object {
        const val CHANNEL = "ironpeak/launcher_icon"
        const val TAG = "IronpeakLauncherIcon"

        // Relative android:name values resolve against the manifest namespace
        // (this class's package), not the application id -- the two only
        // happen to be equal today.
        val NAMESPACE: String = IronpeakActivity::class.java.name.substringBeforeLast('.')
    }
}

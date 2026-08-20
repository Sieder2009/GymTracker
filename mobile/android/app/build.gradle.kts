import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// A release build signed with a different key than whatever a user already
// has installed fails to install at all ("package conflicts with an
// existing package") -- CI has no persistent ~/.android/debug.keystore
// (every runner is a fresh VM), so every debug-signed release build was
// getting a different random signature. key.properties (gitignored; CI
// reconstructs it from repo secrets, see android.yml) points at a real,
// checked-in-nowhere release keystore instead, so every build -- local or
// CI -- signs with the same key and updates install cleanly over each
// other. Missing key.properties (a fresh clone with no keystore set up)
// falls back to the debug key exactly as before, so local development
// still works without it.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.ironpeak.ironpeak_mobile"
    // Explicit, not flutter.compileSdkVersion -- the installed Flutter
    // SDK's own default (34) is now older than what a transitive plugin
    // dependency (flutter_plugin_android_lifecycle, pulled in via
    // file_picker) requires its consumers to compile against.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications' AAR metadata declares this as a
        // hard requirement (its own java.time usage) regardless of our
        // minSdk 26 -- without it, checkReleaseAarMetadata fails the build
        // before compilation even starts.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ironpeak.ironpeak_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // 26, not flutter.minSdkVersion's lower default — Health Connect
        // requires API 26+.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // No key.properties (fresh clone without the release keystore
                // set up) -- fall back to the debug key exactly as before, so
                // `flutter run --release` still works locally. This build
                // won't install over a real release build on a phone that
                // already has one (different signature) -- that's expected;
                // only a build signed with the real release key can update it.
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

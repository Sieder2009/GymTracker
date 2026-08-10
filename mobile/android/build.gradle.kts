allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Some plugins (flutter_timezone, health, ... as of this writing) ship a
// build.gradle with an internally inconsistent Java/Kotlin target for
// their own module -- which newer Kotlin Gradle Plugin versions now
// hard-fail on instead of warning ("Inconsistent JVM-target compatibility
// detected for tasks 'compileReleaseJavaWithJavac' (X) and
// 'compileReleaseKotlin' (Y)").
//
// This has taken five attempts, each fixing one plugin module while
// breaking or missing another -- worth recording why, so nobody
// "simplifies" this back into a broken version:
//
// 1. tasks.withType<JavaCompile/KotlinCompile>().configureEach {} inside
//    allprojects{} fixed :health's Kotlin task but left its Java task
//    unconfigured -- AGP finalizes a library module's JavaCompile task
//    settings from that module's own `android { compileOptions {...} }`
//    during that module's evaluation, and depending on afterEvaluate
//    registration order that can still run after our allprojects-level
//    configureEach did.
// 2. Moving the same raw-task-property assignment into
//    gradle.projectsEvaluated{} (guaranteed to run after every module,
//    including its own afterEvaluate hooks, has finished) fixed :health
//    correctly -- but assigning MATCHING source/targetCompatibility this
//    way makes Gradle invoke javac in `--release` mode, which is stricter
//    about classpath resolution than AGP's own compileOptions-driven setup
//    expects. That broke android.jar visibility for an unrelated
//    Java-only module (flutter_local_notifications).
// 3. Switching to kotlin.jvmToolchain(17) via pluginManager.withPlugin (the
//    officially-recommended, non-raw-property approach) avoided the
//    --release-mode footgun, but toolchain() only sets a *default* --
//    :flutter_timezone's own build.gradle explicitly sets
//    `kotlinOptions.jvmTarget = "1.8"` on its Kotlin task, and that
//    explicit per-task setting still wins over a project-level toolchain
//    default regardless of which registered first.
// 4. gradle.projectsEvaluated + AGP's typed `compileOptions` DSL (instead of
//    attempt 2's raw JavaCompile task property, to dodge its --release-mode
//    regression) fixed :flutter_timezone too -- but crashed the whole build
//    with "sourceCompatibility has been finalized" on CI. AGP locks that
//    property as part of a module's own configuration (finalizeValue()),
//    and by the time our *global* projectsEvaluated hook runs -- guaranteed
//    to fire after every module's own configuration, including AGP's
//    internal finalization -- at least one module has already locked it.
//    Writing to an already-finalized Gradle Property throws instead of
//    silently overriding, unlike a plain var.
// 5. Wrapping that same write in runCatching (best-effort, swallow the
//    already-finalized case per-module) stopped the crash, but for
//    whichever module it swallowed on, Java silently stayed at whatever it
//    already was -- CI then showed exactly which one: :health, stuck at
//    Java 11, while the still-unconditional Kotlin-side override forced it
//    to 17. Recreated the exact "inconsistent target" failure this whole
//    saga is about, just for a module of our own making instead of the
//    plugin's.
//
// The insight all five attempts missed: we don't need to WRITE Java's
// target at all. Every module's Java target is already internally
// consistent by the time it finishes its own evaluation -- the only actual
// problem is Kotlin drifting from it. So: read whatever `compileOptions
// .targetCompatibility` gradle.projectsEvaluated's timing guarantees is
// each module's *final* Java target (a read never throws, unlike the write
// every previous attempt fought with), and set that same module's Kotlin
// tasks to match it exactly. No global "everything must be 17", no
// fighting AGP for a property it's already locked -- just making Kotlin
// follow whatever Java already, stably, is, per module.
gradle.projectsEvaluated {
    subprojects {
        val javaTarget = extensions.findByType<com.android.build.gradle.BaseExtension>()
            ?.compileOptions
            ?.targetCompatibility
            ?: JavaVersion.VERSION_17
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(javaTarget.toString()))
            }
        }
    }
}

// Separately: every plugin gets its own auto-generated Android wrapper
// project (flutter create-style, from that plugin's own template), and
// every one of them declares `compileSdk = flutter.compileSdkVersion` --
// the *installed Flutter SDK's* own bundled default (34 as of writing),
// shared identically across app/ and every plugin subproject alike. That
// default is now older than what a transitive dependency
// (flutter_plugin_android_lifecycle, pulled in via file_picker) requires
// its consumers to compile against (36+) -- bumping just app/build.gradle
// .kts's own compileSdk (already done) only touches :app, not the plugin
// subprojects actually named in the error.
//
// Unlike compileOptions above, compileSdk feeds AGP's classpath
// resolution (which android.jar to compile against) very early in a
// module's own configuration -- gradle.projectsEvaluated's global,
// end-of-build timing is almost certainly too late for a write to still
// matter here, unlike the read-only Kotlin-target fix above. subprojects
// { afterEvaluate {} } is the earlier, per-module hook instead: it runs
// once that module's own script (including its own
// `compileSdk = flutter.compileSdkVersion` line) has finished, but
// before AGP's classpath-relevant work that a plain `subprojects {}}`
// (racing each module's own script execution) can't reliably beat.
subprojects {
    afterEvaluate {
        extensions.findByType<com.android.build.gradle.BaseExtension>()?.compileSdkVersion(36)
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

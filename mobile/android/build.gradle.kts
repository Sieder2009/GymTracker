allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Some plugins (flutter_timezone, health, ... as of this writing) ship a
// build.gradle with an internally inconsistent, outdated Java/Kotlin target
// -- which newer Kotlin Gradle Plugin versions now hard-fail on instead of
// warning. Force every subproject onto the same JVM 17 target
// app/build.gradle.kts already declares.
//
// This has taken four attempts, each fixing one plugin module while
// breaking or missing another -- worth recording why, so nobody "simplifies"
// this back into a broken version:
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
//
// 4. gradle.projectsEvaluated + AGP's typed `compileOptions` DSL (instead of
//    attempt 2's raw JavaCompile task property, to dodge its --release-mode
//    regression) fixed :flutter_timezone too -- but crashed the whole build
//    with "sourceCompatibility has been finalized" on CI. AGP locks that
//    property as part of a module's own configuration (finalizeValue()),
//    and by the time our *global* projectsEvaluated hook runs -- guaranteed
//    to fire after every module's own configuration, including AGP's
//    internal finalization -- at least one module (couldn't identify which
//    from the non-stacktrace CI log) has already locked it. Writing to an
//    already-finalized Gradle Property throws instead of silently
//    overriding, unlike a plain var.
//
// There's no timing that's simultaneously "after every module's own
// explicit override" (needed to win, same reason attempt 1 lost) and
// "before AGP finalizes the DSL property" (needed to not crash) for every
// module at once -- different modules finalize at different points in
// their own lifecycle. So: best-effort via the DSL, swallowing the
// already-finalized case per-module instead of failing the whole build.
// The Kotlin-side task-level override has never itself thrown across any
// of the four attempts, so it stays unconditional.
gradle.projectsEvaluated {
    subprojects {
        runCatching {
            extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }.onFailure {
            logger.info("Skipping Java 17 override for $name -- already finalized: ${it.message}")
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
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

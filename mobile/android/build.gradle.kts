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
// The combination that actually closes every hole: gradle.projectsEvaluated
// (attempt 2's proven "always the last writer" timing, so it wins over
// flutter_timezone's own explicit kotlinOptions the same way it won for
// :health) applying Java's target through AGP's own typed `compileOptions`
// DSL instead of a raw JavaCompile task property (avoids attempt 2's
// --release-mode regression) plus a task-level Kotlin override (since
// attempt 3 already proved a plain toolchain default isn't always enough).
gradle.projectsEvaluated {
    subprojects {
        extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
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

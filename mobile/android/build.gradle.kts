allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Some plugins (flutter_timezone, health, ... as of this writing) ship a
// build.gradle with an internally inconsistent Java/Kotlin target -- e.g.
// Java 11 but Kotlin's default of 1.8 -- which newer Kotlin Gradle Plugin
// versions now hard-fail on instead of warning. Force every Kotlin-enabled
// subproject onto the same JVM 17 target app/build.gradle.kts already
// declares.
//
// Two earlier attempts manually assigned sourceCompatibility/
// targetCompatibility as raw String properties directly on JavaCompile/
// KotlinCompile tasks (once in allprojects{}, then in gradle.
// projectsEvaluated{} to guarantee we ran last). The second attempt did
// fix the original :health mismatch -- but assigning matching source/
// targetCompatibility this way makes Gradle invoke javac in `--release`
// mode, which is stricter about classpath resolution than AGP's own
// compileOptions-driven setup expects, and broke android.jar visibility
// for an unrelated Java-only module (flutter_local_notifications) that
// was never part of the original problem.
//
// A JVM *toolchain* avoids both failure modes: it's a first-class concept
// both AGP and the Kotlin Gradle Plugin understand and coordinate through
// (this is literally what the original Gradle error suggested trying),
// rather than a raw task property another plugin's build.gradle can
// silently overwrite, or that can push a task into an unexpected compile
// mode. Registered via pluginManager.withPlugin so it applies the moment
// each module's own Kotlin plugin does, before that module's own
// build.gradle can configure anything else.
subprojects {
    pluginManager.withPlugin("org.jetbrains.kotlin.android") {
        extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
            jvmToolchain(17)
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

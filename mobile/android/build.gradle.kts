allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Some plugins (flutter_timezone, health, ... as of this writing) ship a
// build.gradle with an internally inconsistent Java/Kotlin target -- e.g.
// Java 11 but Kotlin's default of 1.8 -- which newer Kotlin Gradle Plugin
// versions now hard-fail on instead of warning. Force every subproject
// (app + every plugin module) to the same JVM 17 target app/build.gradle.kts
// already declares.
//
// Two earlier attempts at this both configured `tasks.withType<...>()
// .configureEach {...}` directly inside `allprojects {}` -- once only for
// the Kotlin task, then for both Java and Kotlin tasks. Both still lost to
// the plugin's own `android { compileOptions {...} }` for the *Java* task
// specifically: AGP finalizes a library module's JavaCompile task's
// sourceCompatibility from its own build.gradle during that module's
// evaluation, and depending on internal afterEvaluate registration order
// that can still run after our allprojects-level configureEach did,
// re-overwriting it (Kotlin's task happened to resolve fine, Java's didn't).
//
// `gradle.projectsEvaluated {}` sidesteps the whole registration-order
// question: it only runs once *every* project in the build (including each
// plugin module's own afterEvaluate hooks) has fully finished evaluating,
// so this is unconditionally the last writer.
gradle.projectsEvaluated {
    subprojects {
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
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

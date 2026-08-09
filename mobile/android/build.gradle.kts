allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Some plugins (flutter_timezone, health, ... as of this writing) ship a
    // build.gradle with an internally inconsistent Java/Kotlin target --
    // e.g. Java 11 but Kotlin's default of 1.8 -- which newer Kotlin Gradle
    // Plugin versions now hard-fail on instead of warning. Force every
    // subproject (app + every plugin module) to the same JVM 17 target
    // app/build.gradle.kts already declares.
    //
    // Both blocks configure the *tasks* directly (`tasks.withType<...>`),
    // not `android { compileOptions {...} }` on the project -- that eager,
    // project-level form gets silently overwritten when a plugin's own
    // build.gradle sets its own (stale) compileOptions afterwards, which is
    // exactly what happened here: forcing only the Kotlin task to 17 while
    // leaving the Java task at the plugin's original 11 just traded one
    // mismatch (11/1.8) for another (11/17). Configuring both task types
    // this way applies at task-configuration time, after every project's
    // own android{} block has already run, so nothing can override it.
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

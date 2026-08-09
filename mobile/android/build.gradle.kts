allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Some plugins (flutter_timezone as of this writing) ship a build.gradle
    // with an internally inconsistent Java/Kotlin target -- e.g. Java 11 but
    // Kotlin's default of 1.8 -- which newer Kotlin Gradle Plugin versions
    // now hard-fail on instead of warning. Force every subproject (app +
    // every plugin module) to the same JVM 17 target app/build.gradle.kts
    // already declares, so no plugin's own stale gradle file can conflict.
    pluginManager.withPlugin("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
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

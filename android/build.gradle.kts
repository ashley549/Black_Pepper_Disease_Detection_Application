allprojects {
    repositories {
        google()
        mavenCentral()
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

// The tflite_flutter plugin module builds its Java at target 11 (pinned by
// the Flutter Gradle plugin) but its Kotlin defaults to the JDK 17 toolchain,
// which fails with "Inconsistent JVM Target Compatibility". Pinning the
// module's Kotlin to JVM 11 matches the Java side and fixes the build.
subprojects {
    if (name == "tflite_flutter") {
        pluginManager.withPlugin("org.jetbrains.kotlin.android") {
            tasks
                .withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java)
                .configureEach {
                    compilerOptions.jvmTarget.set(
                        org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
                    )
                }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

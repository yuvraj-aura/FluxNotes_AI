allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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

subprojects {
    // Define the fixing logic in one place
    val fixAndroid = {
        val android = project.extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
        if (android != null) {
            // FORCE the SDK version to 36 to fix the lStar error
            android.compileSdk = 36
            
            // Fix the Namespace error if it exists
            if (android.namespace == null) {
                android.namespace = project.group.toString()
            }
        }
    }

    // "Time Travel" Check:
    // If the project is already done, fix it NOW.
    // If it's still loading, wait until it's done (afterEvaluate).
    if (project.state.executed) {
        fixAndroid()
    } else {
        project.afterEvaluate {
            fixAndroid()
        }
    }
}
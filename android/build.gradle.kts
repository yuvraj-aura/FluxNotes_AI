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

subprojects {
    afterEvaluate {
        val android = extensions.findByName("android")
        if (android != null) {
             val namespaceProp = android.javaClass.getMethod("getNamespace")
             if (namespaceProp.invoke(android) == null) {
                 val setNamespaceStart = android.javaClass.getMethod("setNamespace", String::class.java)
                 setNamespaceStart.invoke(android, "com.fluxnotes.${project.name.replace("-", "_")}")
             }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

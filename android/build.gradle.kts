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

subprojects {
    val project = this
    if (project.state.executed) {
        val android = project.extensions.findByType<com.android.build.gradle.BaseExtension>()
        if (android != null && android.namespace == null) {
            android.namespace = project.group.toString()
        }
    } else {
        project.afterEvaluate {
            val android = project.extensions.findByType<com.android.build.gradle.BaseExtension>()
            if (android != null && android.namespace == null) {
                android.namespace = project.group.toString()
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

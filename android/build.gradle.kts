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

    plugins.withId("com.android.library") {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            val getNamespace = androidExt.javaClass.getMethod("getNamespace")
            val currentNs = getNamespace.invoke(androidExt) as? String
            if (currentNs.isNullOrBlank()) {
                val manifestFile = file("src/main/AndroidManifest.xml")
                val pkgFromManifest = if (manifestFile.exists()) {
                    val match = Regex("""package="([^"]+)"""").find(manifestFile.readText())
                    match?.groupValues?.getOrNull(1)
                } else {
                    null
                }
                val fallbackNs = pkgFromManifest ?: "com.example.${project.name.replace('-', '_')}"
                val setNamespace = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                setNamespace.invoke(androidExt, fallbackNs)
            }
            if (project.name == "on_audio_query_android") {
                val components = extensions.findByName("androidComponents")
                if (components != null) {
                    val finalizeDslMethod = components.javaClass.methods.firstOrNull {
                        it.name == "finalizeDsl" &&
                            it.parameterCount == 1 &&
                            it.parameterTypes[0] == org.gradle.api.Action::class.java
                    }
                    finalizeDslMethod?.invoke(
                        components,
                        org.gradle.api.Action<Any> {
                            try {
                                this.javaClass
                                    .getMethod("setCompileSdk", Int::class.javaObjectType)
                                    .invoke(this, 37)
                            } catch (_: Throwable) {
                                this.javaClass
                                    .getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                                    .invoke(this, 37)
                            }
                        },
                    )
                }
            }
        }
    }

    if (project.name != "app") {
        tasks.configureEach {
            if (this.javaClass.name.contains("KotlinCompile")) {
                try {
                    val javaTask = project.tasks
                        .withType(org.gradle.api.tasks.compile.JavaCompile::class.java)
                        .firstOrNull()
                    val targetCompat = javaTask?.targetCompatibility ?: "17"
                    val normalizedTarget = if (targetCompat == "1.8") "8" else targetCompat
                    val compilerOptions = this.javaClass.getMethod("getCompilerOptions").invoke(this)
                    val jvmTargetProp = compilerOptions.javaClass.getMethod("getJvmTarget").invoke(compilerOptions)
                    val jvmTargetEnumClass = Class.forName(
                        "org.jetbrains.kotlin.gradle.dsl.JvmTarget",
                        true,
                        compilerOptions.javaClass.classLoader,
                    )
                    val fromTarget = jvmTargetEnumClass.getMethod("fromTarget", String::class.java)
                    val targetEnum = fromTarget.invoke(null, normalizedTarget)
                    jvmTargetProp.javaClass.getMethod("set", Any::class.java).invoke(jvmTargetProp, targetEnum)
                } catch (_: Throwable) {
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

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

// پلاگین‌های قدیمی (مثل vosk_flutter 0.3.48) که namespace ندارند —
// AGP 8+ بدون namespace خطا می‌دهد، پس از group پروژه namespace می‌سازیم.
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.api.dsl.LibraryExtension> {
            if (namespace.isNullOrBlank()) {
                namespace = group.toString().ifBlank { "com.example.${name}" }
            }
            // پکیج‌های قدیمی (مثل vosk_flutter) با compileSdk پایین ساخته شده‌اند؛
            // وابستگی‌های androidx آنها به SDK بالاتر نیاز دارد.
            compileSdk = 36
        }
    }
    // برخی پکیج‌ها compileSdk را بعداً ست می‌کنند؛ بعد از ارزیابی دوباره اعمال کن.
    fun applyCompileSdk() {
        extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)?.let { lib ->
            val current = lib.compileSdk
            if (current == null || current < 34) {
                lib.compileSdk = 36
            }
        }
    }
    if (state.executed) {
        applyCompileSdk()
    } else {
        afterEvaluate { applyCompileSdk() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

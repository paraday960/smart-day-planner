import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "ir.smartday.smart_day_planner"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ir.smartday.smart_day_planner"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // امضای انتشار - اگر key.properties وجود داشت از آن استفاده می‌کند، وگرنه debug
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // اگر key.properties نبود، امضای release مقدار نمی‌گیرد و task
            // «preReleaseBuild» در پایین همین فایل، ساخت را با پیام واضح
            // متوقف می‌کند — دیگر هرگز بیلد «release» با کلید debug امضا
            // نمی‌شود (ریسک انتشار ناخواسته).
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                null
            }
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// ── محافظ امضای release ─────────────────────────────────────────────
// اگر key.properties موجود نباشد، هر build از نوع release (APK یا AAB)
// با خطای واضح متوقف می‌شود. build های debug تحت تأثیر قرار نمی‌گیرند.
tasks.configureEach {
    if (name == "preReleaseBuild") {
        doFirst {
            if (!keystorePropertiesFile.exists()) {
                throw GradleException(
                    "android/key.properties یافت نشد. " +
                        "برای ساخت release: فایل android/key.properties را از روی " +
                        "key.properties.example بسازید (یا در CI از Secrets استفاده کنید). " +
                        "ساخت release بدون کلید امضای واقعی مجاز نیست."
                )
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

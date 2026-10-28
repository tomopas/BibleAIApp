import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing material comes from android/key.properties, which is
// gitignored. CI writes that file from repository secrets before building.
// Without it, release builds fall back to the debug key so that a local
// `flutter build apk --release` still works (never upload those artifacts).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
}

// Debug and profile builds talk to the emulator over plain http, so cleartext
// traffic stays enabled there. Release builds are HTTPS-only unless the build
// explicitly opts in, e.g. for a church LAN server without TLS:
//   flutter build apk --release -PallowCleartext=true
val releaseAllowsCleartext =
    (project.findProperty("allowCleartext") as String? ?: "false").toBoolean()

android {
    namespace = "com.bibleai.bible_ai_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Change this before the first Play Store upload; the ID cannot
        // be changed afterwards. Keep namespace in sync if you also rename the
        // Kotlin package.
        applicationId = "com.bibleai.bible_ai_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["usesCleartextTraffic"] = "true"
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasReleaseSigning) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
            manifestPlaceholders["usesCleartextTraffic"] =
                releaseAllowsCleartext.toString()
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

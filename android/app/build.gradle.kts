import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningProperties = Properties().apply {
    val propertiesFile = rootProject.file("key.properties")
    if (propertiesFile.isFile) {
        propertiesFile.inputStream().use(::load)
    }
}

fun releaseSigningValue(property: String, environmentVariable: String): String? =
    System.getenv(environmentVariable)?.takeIf(String::isNotBlank)
        ?: releaseSigningProperties.getProperty(property)?.takeIf(String::isNotBlank)

val releaseStorePath = releaseSigningValue("storeFile", "ANDROID_KEYSTORE_PATH")
val releaseKeyAlias = releaseSigningValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = releaseSigningValue("keyPassword", "ANDROID_KEY_PASSWORD")
val releaseStorePassword = releaseSigningValue("storePassword", "ANDROID_STORE_PASSWORD")
val releaseStoreFile = releaseStorePath?.let(rootProject::file)
val releaseSigningConfigured = releaseStoreFile?.isFile == true &&
    !releaseKeyAlias.isNullOrBlank() &&
    !releaseKeyPassword.isNullOrBlank() &&
    !releaseStorePassword.isNullOrBlank()

if (
    gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) } &&
    !releaseSigningConfigured
) {
    throw GradleException(
        "Release signing is not configured. Set android/key.properties or the " +
            "ANDROID_KEYSTORE_PATH, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD, and " +
            "ANDROID_STORE_PASSWORD environment variables. Debug keys are not used for release builds."
    )
}

android {
    namespace = "com.github.neisbila32cpu.estoqueuan"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Keep this distribution identity stable; changing it creates a separate app and database.
        applicationId = "com.github.neisbila32cpu.estoqueuan"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (releaseSigningConfigured) {
        signingConfigs {
            create("release") {
                storeFile = releaseStoreFile
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storePassword = releaseStorePassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseSigningConfigured) {
                signingConfigs.getByName("release")
            } else {
                null
            }
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

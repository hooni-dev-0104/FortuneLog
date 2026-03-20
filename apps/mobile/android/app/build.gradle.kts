import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}
val hasReleaseSigning = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !keystoreProperties.getProperty(it).isNullOrBlank() }
val allowDebugSignedRelease = providers
    .environmentVariable("ALLOW_DEBUG_SIGNED_RELEASE")
    .orNull
    ?.toBooleanStrictOrNull() == true
val releaseSigningError =
    "Release signing is required. Configure android/key.properties or set " +
        "ALLOW_DEBUG_SIGNED_RELEASE=true only for local verification."

if (!hasReleaseSigning) {
    logger.lifecycle(
        "Android release signing is not configured. " +
            "Create android/key.properties from key.properties.example to use a real release keystore.",
    )
}

android {
    namespace = "com.fortunelog.mobile"
    compileSdk = flutter.compileSdkVersion
    // Keep in sync with Android plugin deps (app_links/path_provider/shared_preferences/url_launcher).
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.fortunelog.mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            } else if (allowDebugSignedRelease) {
                // Keep explicit local verification unblocked when secrets are intentionally absent.
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

gradle.taskGraph.whenReady {
    val requiresReleaseSigning = allTasks.any { task ->
        val taskName = task.name.lowercase()
        taskName.contains("release") &&
            (
                taskName.startsWith("assemble") ||
                    taskName.startsWith("bundle") ||
                    taskName.startsWith("package") ||
                    taskName.startsWith("sign")
            )
    }

    if (requiresReleaseSigning && !hasReleaseSigning && !allowDebugSignedRelease) {
        throw GradleException(releaseSigningError)
    }
}

flutter {
    source = "../.."
}

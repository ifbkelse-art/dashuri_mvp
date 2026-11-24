import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload-key signing for Play. android/key.properties is git-ignored and holds
// storeFile, storePassword, keyAlias, keyPassword (never commit it or the keystore).
// Without it, release builds keep the debug key and work locally only.
val keyProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasUploadKey = keyProperties.getProperty("storeFile") != null

android {
    namespace = "com.bkenterprises.dashuri_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        // TODO(founder): confirm before first Play upload — the applicationId can never change afterwards.
        applicationId = "com.bkenterprises.dashuri"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Set DASHURI_PLAY_CLOUD_PROJECT_NUMBER in gradle.properties or the environment (0 = unset).
        manifestPlaceholders["playCloudProjectNumber"] =
            (project.findProperty("DASHURI_PLAY_CLOUD_PROJECT_NUMBER") ?: System.getenv("DASHURI_PLAY_CLOUD_PROJECT_NUMBER") ?: "0").toString()
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = rootProject.file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Upload key when android/key.properties exists (Play App Signing holds the app key);
            // otherwise the debug key, which keeps `flutter build apk --release` working locally only.
            signingConfig = if (hasUploadKey) signingConfigs.getByName("upload") else signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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

dependencies {
    implementation("com.google.android.play:integrity:1.4.0")
}

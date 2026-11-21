plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

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

    buildTypes {
        release {
            // TODO(release): replace with the upload key; Play App Signing holds the app key.
            // Debug signing keeps `flutter build apk --release` working locally only.
            signingConfig = signingConfigs.getByName("debug")
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

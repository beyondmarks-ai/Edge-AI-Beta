plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.beyondmarks.edgeai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.beyondmarks.edgeai"
        minSdk = 29
        ndk {
            // llama.cpp runtime bundles are available for 64-bit Android.
            val targets = (project.findProperty("target-platform") as? String)
                ?.split(",") ?: listOf("android-arm64", "android-x64")
            abiFilters.clear()
            if ("android-arm64" in targets) abiFilters += "arm64-v8a"
            if ("android-x64" in targets) abiFilters += "x86_64"
            require(abiFilters.isNotEmpty()) { "Offline chat requires a 64-bit Android target." }
        }
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

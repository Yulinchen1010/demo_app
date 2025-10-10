plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
<<<<<<< HEAD
    namespace = "com.example.fatigue_tree"
    compileSdk = 34
=======
    namespace = "com.example.fatigue_tree_v4" 
    compileSdk = 36
>>>>>>> feature/realtime-ai-cloud

     // ← 新 namespace
    defaultConfig {
<<<<<<< HEAD
        applicationId = "com.example.fatigue_tree"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
        multiDexEnabled = true
=======
        applicationId = "com.example.fatigue_tree_v4"   // ← v4（最關鍵）
        minSdk = 24
        targetSdk = 36
        versionCode = 4
        versionName = "0.4"
>>>>>>> feature/realtime-ai-cloud
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}

flutter { source = "../.." }

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
}
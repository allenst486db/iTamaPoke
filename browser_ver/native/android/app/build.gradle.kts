plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.itamapoke.web"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.itamapoke.web"
        minSdk = 26   // WKWebView-equivalent WASM streaming compile needs a modern WebView
        targetSdk = 34
        versionCode = 1
        versionName = "0.1"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.7.0")
}

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.itamapoke.web"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.itamapoke.web"
        minSdk = 26   // WASM streaming compile + WebViewAssetLoader need a modern WebView
        targetSdk = 34
        versionCode = 1
        versionName = "0.9.0"
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
    implementation("androidx.activity:activity-ktx:1.9.0")
    // WebViewAssetLoader: serves the bundled web/ folder from a real https
    // origin so IndexedDB and the service worker behave (see MainActivity).
    implementation("androidx.webkit:webkit:1.11.0")
}

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.spinecare.app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.spinecare.app"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "0.1.0"
    }
    signingConfigs {
        create("ci") {
            val ks = System.getenv("SPINECARE_KEYSTORE")
            if (!ks.isNullOrBlank()) {
                storeFile = file(ks)
                storePassword = System.getenv("SPINECARE_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("SPINECARE_KEY_ALIAS")
                keyPassword = System.getenv("SPINECARE_KEY_PASSWORD")
            }
        }
    }
    buildTypes {
        debug { isMinifyEnabled = false }
        release {
            // Prototype release: R8 kept off so MediaPipe/OkHttp reflection stays safe.
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            signingConfig = if (!System.getenv("SPINECARE_KEYSTORE").isNullOrBlank()) {
                signingConfigs.getByName("ci")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { viewBinding = true }
    packaging { resources.excludes += "/META-INF/{AL2.0,LGPL2.1}" }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.4")
    implementation("androidx.activity:activity-ktx:1.9.1")
    implementation("androidx.fragment:fragment-ktx:1.8.2")
    implementation("androidx.recyclerview:recyclerview:1.3.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.1")
    // Camera
    implementation("androidx.camera:camera-core:1.3.4")
    implementation("androidx.camera:camera-camera2:1.3.4")
    implementation("androidx.camera:camera-lifecycle:1.3.4")
    implementation("androidx.camera:camera-view:1.3.4")
    // On-device pose: MediaPipe Tasks Vision (BlazePose 33 landmarks)
    implementation("com.google.mediapipe:tasks-vision:0.10.14")
    // BLE uses platform android.bluetooth APIs (BlePostureClient) — no extra artifact
    // Health Connect
    implementation("androidx.health.connect:connect-client:1.1.0-alpha06")
    // Charts
    implementation("com.github.PhilJay:MPAndroidChart:v3.1.0")
    // HTTP/WS for GPU server
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
    testImplementation("junit:junit:4.13.2")
}

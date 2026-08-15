plugins {
    id("com.android.application")
}

android {
    namespace = "top.x67611.sidekeycirclesearch"
    compileSdk = 36

    defaultConfig {
        applicationId = "top.x67611.sidekeycirclesearch"
        minSdk = 36
        targetSdk = 36
        versionCode = 7
        versionName = "1.2.2"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    packaging {
        resources {
            merges += "META-INF/xposed/*"
        }
    }
}

dependencies {
    compileOnly("io.github.libxposed:api:102.0.0")
}

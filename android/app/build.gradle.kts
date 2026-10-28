import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")

    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration

    id("kotlin-android")

    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}


// ============================================================
// Load Keystore Properties
// ============================================================

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}


android {
    namespace = "com.digitalmitro.digital_mitro"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion


    // ============================================================
    // Java / Kotlin Configuration
    // ============================================================

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // Required by flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }


    // ============================================================
    // Default App Configuration
    // ============================================================

    defaultConfig {
        applicationId = "com.digitalmitro.digital_mitro"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
    }


    // ============================================================
    // Signing Configuration
    // ============================================================

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String

            storeFile = keystoreProperties["storeFile"]?.let {
                file(it)
            }

            storePassword = keystoreProperties["storePassword"] as String
        }
    }


    // ============================================================
    // Build Types
    // ============================================================

    buildTypes {

        release {
            // Use our release keystore instead of the debug keystore
            signingConfig = signingConfigs.getByName("release")

            // You can enable these later if you want R8/ProGuard optimization
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}


dependencies {

    // Required by flutter_local_notifications (v10+)
    //
    // isCoreLibraryDesugaringEnabled only enables desugaring.
    // This dependency provides the actual desugared Java APIs.
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.4"
    )
}


flutter {
    source = "../.."
}
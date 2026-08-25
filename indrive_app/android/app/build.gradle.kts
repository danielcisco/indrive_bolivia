import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.firebase-perf")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// API key de Google Maps (Sprint 4.1a): vive en local.properties (ya
// gitignored, mismo patrón que flutter.sdk) para no commitear la clave.
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}
val mapsApiKey: String = localProperties.getProperty("MAPS_API_KEY", "")

android {
    namespace = "com.example.indrive_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Requerido por flutter_local_notifications (Sprint 3.2).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Sin applicationId por defecto: cada flavor (abajo) fija el suyo.
        // Cliente y Repartidor son apps Android reales que antes compartían
        // "com.example.indrive_app" y por eso no podían instalarse juntas en
        // el mismo dispositivo (pendiente técnico post Sprint 5.1). Admin
        // nunca compila a Android (es Flutter Web puro), así que no
        // necesita flavor propio.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    flavorDimensions += "app"
    productFlavors {
        create("cliente") {
            dimension = "app"
            applicationId = "bo.villazon.indriveentregas.cliente"
        }
        create("repartidor") {
            dimension = "app"
            applicationId = "bo.villazon.indriveentregas.repartidor"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Requerido por flutter_local_notifications (core library desugaring).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

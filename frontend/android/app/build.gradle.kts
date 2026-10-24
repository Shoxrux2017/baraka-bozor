import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/**
 * The values given to `flutter build` or `flutter run` with `--dart-define`,
 * which Flutter passes to Gradle base64-encoded and comma-separated. Read here
 * for the one native consumer, the Google Maps key (`DL-86` (2)).
 */
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.filter { it.isNotEmpty() }
        ?.associate { entry ->
            val pair = String(Base64.getDecoder().decode(entry))
            pair.substringBefore("=") to pair.substringAfter("=", "")
        }
        ?: emptyMap()

android {
    namespace = "uz.barakabozor.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications uses java.time, which Android 8 lacks.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Fixed by decision D-2 of S01-FE-001. It cannot change after a Play
        // upload, which is why it was decided before these trees existed.
        applicationId = "uz.barakabozor.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 8.0, API 26: the Owner chose it as the oldest Android the
        // app supports (`DL-33` (10)).
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Never committed: the key reaches the build from the command line
        // only, and the manifest takes it as a placeholder.
        manifestPlaceholders["googleMapsApiKey"] = dartDefines["GOOGLE_MAPS_API_KEY"] ?: ""
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

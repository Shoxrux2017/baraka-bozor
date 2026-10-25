import java.util.Base64
import java.util.Properties

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

/**
 * Why a release build cannot be signed, or null when `key.properties` is
 * complete. The upload key lives in the gitignored `frontend/android/key.properties`
 * and the keystore outside the repository (`DL-116` (1)).
 */
val releaseSigningProblem: String? = run {
    val file = rootProject.file("key.properties")
    if (!file.isFile) return@run "the file is missing"
    // Not the exception's text: it may echo a value of the file.
    val keys = try {
        Properties().apply { file.inputStream().use { load(it) } }
    } catch (e: Exception) {
        return@run "it cannot be read"
    }
    for (name in listOf("storeFile", "storePassword", "keyAlias", "keyPassword")) {
        if (keys.getProperty(name).isNullOrBlank()) return@run "it has no $name"
    }
    if (!file(keys.getProperty("storeFile").trim()).isFile) {
        return@run "the keystore its storeFile names does not exist"
    }
    null
}

android {
    namespace = "uz.barakabozor.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications is built with core library desugaring, so the app must enable it too.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Fixed by decision D-2 of S01-FE-001. It cannot change after a Play
        // upload, which is why it was decided before these trees existed.
        applicationId = "uz.barakabozor.app"
        // Android 8.0, API 26: the Owner chose it as the oldest Android the
        // app supports (`DL-33` (10)).
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // The version code and name come from `version` in pubspec.yaml (`DL-116` (2)).
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Never committed: the key reaches the build from the command line
        // only, and the manifest takes it as a placeholder.
        manifestPlaceholders["googleMapsApiKey"] = dartDefines["GOOGLE_MAPS_API_KEY"] ?: ""
    }

    signingConfigs {
        // Created only from a complete key.properties, so a release is never
        // signed with the debug key or left unsigned (`DL-116` (1)).
        if (releaseSigningProblem == null) {
            create("release") {
                val keys = Properties().apply {
                    rootProject.file("key.properties").inputStream().use { load(it) }
                }
                storeFile = file(keys.getProperty("storeFile").trim())
                storePassword = keys.getProperty("storePassword")
                keyAlias = keys.getProperty("keyAlias")
                keyPassword = keys.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

// Only a release task fails here; debug, profile, tests and the web build need no key.
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst {
        releaseSigningProblem?.let {
            throw GradleException(
                "A release build is signed with the upload key from frontend/android/key.properties " +
                    "(DL-116 (1)): $it. See docs/store/README.md.",
            )
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

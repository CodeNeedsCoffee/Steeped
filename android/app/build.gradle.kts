import java.util.Properties

// Release signing: read from android/key.properties locally (gitignored) or from
// ANDROID_KEYSTORE_* environment variables in CI. With neither present the release
// build falls back to the debug key so `flutter run --release` keeps working.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
fun signingValue(prop: String, env: String): String? =
    keyProps.getProperty(prop) ?: System.getenv(env)

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.codeneedscoffee.steeped"
    // permission_handler_android requires compileSdk 37+; Flutter's bundled
    // default (flutter.compileSdkVersion) hasn't caught up yet, so pin it
    // explicitly.
    //
    // Bug fix 2026-09-22 (evan: lock-screen/quick-settings media controls
    // never showing up — confirmed live via `adb shell dumpsys activity
    // services`: `com.ryanheise.audioservice.AudioService` had
    // `startForegroundCount=0` and `getFgsAllowStart_new=DENIED`, even
    // though `getFgsAllowStart_legacy=PROC_STATE_TOP` would have allowed
    // it). `targetSdk` used to be raised to 37 to match compileSdk, per
    // AGP's general recommendation — but Android's foreground-service-start
    // restrictions are gated on the app's declared `targetSdkVersion`, not
    // `compileSdk`, and `audio_service` 0.18.19 (the latest published
    // version — confirmed via `flutter pub outdated`, nothing newer exists)
    // predates whatever new bind-context restriction API 37 introduces:
    // its own build.gradle only asks for compileSdk 35. Targeting 37
    // silently broke its `startForeground()` call, which in turn meant no
    // notification ever posted, no `MediaSession` ever activated, and none
    // of the `mediaPlayback` foreground-service Doze/background exemptions
    // this app relies on for lock-screen playback ever actually applied.
    // compileSdk stays at 37 (still needed to *compile* against
    // permission_handler_android); targetSdk drops back to Flutter's own
    // tested default so the app is held to the SDK level every plugin here
    // actually supports at runtime.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.codeneedscoffee.steeped"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val path = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")
            if (path != null) {
                storeFile = file(path)
                storePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            val releaseSigning = signingConfigs.getByName("release")
            signingConfig =
                if (releaseSigning.storeFile != null) releaseSigning
                else signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

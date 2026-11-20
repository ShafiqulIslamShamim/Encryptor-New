import groovy.json.JsonSlurper
import java.util.Base64

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val logger = project.logger
var secrets: Map<String, Any?>? = null

val json = System.getenv("SIGNATURE_SECRETS")

if (json.isNullOrEmpty()) {
    logger.warn("⚠ env not found. Using local project files if available.")
} else {
    try {
        logger.lifecycle("Parsing env...")

        secrets = JsonSlurper().parseText(json) as? Map<String, Any?>

        val keystoreDir = file("keystore")
        keystoreDir.mkdirs()

        val keystoreBase64 = secrets?.get("RELEASE_KEYSTORE_BASE64") as? String
        if (keystoreBase64 != null) {
            val keystore = file("keystore/releasekey.jks")
            keystore.writeBytes(Base64.getDecoder().decode(keystoreBase64))
            logger.lifecycle("releasekey.jks restored.")
        }
    } catch (e: Exception) {
        logger.error("Failed to restore secrets.", e)
        throw e
    }
}

android {
    namespace = "com.shamim.encryptor"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.shamim.encryptor"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (secrets != null) {
                logger.lifecycle("Configuring release signing from env...")

                storeFile = file(secrets!!["STORE_FILE"] as String)
                storePassword = secrets!!["STORE_PASSWORD"] as String
                keyAlias = secrets!!["KEY_ALIAS"] as String
                keyPassword = secrets!!["KEY_PASSWORD"] as String

                logger.lifecycle("Release signing configured.")
            } else {
                logger.warn("⚠ No signing configuration found.")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

// Firebase：仅在存在 google-services.json 时启用，避免未配置环境直接构建失败
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    println("[firebase] google-services.json not found, skip google-services plugin")
}

android {
    // 从统一配置文件读取 Application ID 与签名信息
    val androidConfigProps = Properties()
    val configDir = rootProject.projectDir.parentFile.resolve("config/android")
    val configFile = configDir.resolve("app_config.properties")
    val localConfigFile = configDir.resolve("app_config.local.properties")
    if (configFile.exists()) {
        configFile.inputStream().use { androidConfigProps.load(it) }
    }
    if (localConfigFile.exists()) {
        localConfigFile.inputStream().use { androidConfigProps.load(it) }
    }

    fun prop(key: String, default: String = ""): String =
        androidConfigProps.getProperty(key, default)

    val applicationIdFromConfig = prop("APPLICATION_ID", "com.chatlyme.app")

    namespace = applicationIdFromConfig
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Application ID 统一从配置文件读取
        applicationId = applicationIdFromConfig
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Patrol E2E 测试配置
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
    }

    signingConfigs {
        // 尝试根据配置创建 release 签名；如配置不完整则回退到 debug
        val keystoreFile = prop("KEYSTORE_FILE")
        val keystorePassword = prop("KEYSTORE_PASSWORD")
        val keyAlias = prop("KEY_ALIAS")
        val keyPassword = prop("KEY_PASSWORD")
        val releaseKeystoreFile = if (keystoreFile.isNotBlank()) rootProject.file(keystoreFile) else null

        if (
            releaseKeystoreFile?.exists() == true &&
            keystorePassword.isNotBlank() &&
            keyAlias.isNotBlank() &&
            keyPassword.isNotBlank()
        ) {
            create("release") {
                storeFile = releaseKeystoreFile
                storePassword = keystorePassword
                this.keyAlias = keyAlias
                this.keyPassword = keyPassword
            }
        } else if (
            keystoreFile.isNotBlank() ||
            keystorePassword.isNotBlank() ||
            keyAlias.isNotBlank() ||
            keyPassword.isNotBlank()
        ) {
            println("[signing] release signing config incomplete or keystore missing, use debug signing")
        }
    }

    buildTypes {
        release {
            // 如已配置 release 签名，则使用；否则回退到 debug 签名，保证开发环境可用
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring（flutter_local_notifications 需要）
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Patrol E2E 测试依赖（版本需与 Flutter 插件兼容）
    androidTestImplementation("androidx.test:runner:1.5.1")
    androidTestImplementation("androidx.test:rules:1.2.0")
    androidTestImplementation("androidx.test.ext:junit:1.1.3")
}

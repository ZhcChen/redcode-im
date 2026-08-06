import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
    id("com.google.devtools.ksp")
    jacoco
}

dependencyLocking {
    lockAllConfigurations()
}

android {
    namespace = "com.redcode.im.androidapp"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.redcode.im.androidapp"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "2.0.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        val apiBaseUrl = providers.gradleProperty("redcode.apiBaseUrl").orElse("http://10.0.2.2:8010")
        val wsUrl = providers.gradleProperty("redcode.wsUrl").orElse("ws://10.0.2.2:8010/ws")
        val useRemoteAuth = providers.gradleProperty("redcode.useRemoteAuth").orElse("false")
        buildConfigField("String", "REDCODE_API_BASE_URL", "\"${apiBaseUrl.get()}\"")
        buildConfigField("String", "REDCODE_WS_URL", "\"${wsUrl.get()}\"")
        buildConfigField("boolean", "REDCODE_USE_REMOTE_AUTH", useRemoteAuth.get())
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlin {
        jvmToolchain(21)
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }

    val releaseSigningProperties =
        mapOf(
            "storeFile" to providers.gradleProperty("redcode.signing.storeFile").orNull,
            "storePassword" to providers.gradleProperty("redcode.signing.storePassword").orNull,
            "keyAlias" to providers.gradleProperty("redcode.signing.keyAlias").orNull,
            "keyPassword" to providers.gradleProperty("redcode.signing.keyPassword").orNull,
        )
    val configuredSigningProperties = releaseSigningProperties.filterValues { !it.isNullOrBlank() }
    require(configuredSigningProperties.isEmpty() || configuredSigningProperties.size == releaseSigningProperties.size) {
        "Android release signing properties must be either complete or absent"
    }

    signingConfigs {
        if (configuredSigningProperties.isNotEmpty()) {
            create("release") {
                storeFile = file(releaseSigningProperties.getValue("storeFile")!!)
                storePassword = releaseSigningProperties.getValue("storePassword")
                keyAlias = releaseSigningProperties.getValue("keyAlias")
                keyPassword = releaseSigningProperties.getValue("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            enableUnitTestCoverage = true
        }
        release {
            isMinifyEnabled = false
            signingConfigs.findByName("release")?.let { signingConfig = it }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    testOptions {
        unitTests.isIncludeAndroidResources = true
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2025.04.01")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.9.0")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.1")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.datastore:datastore-preferences:1.2.1")
    implementation("androidx.room:room-runtime:2.8.4")
    implementation("androidx.room:room-ktx:2.8.4")
    ksp("androidx.room:room-compiler:2.8.4")
    // e2ee-core C ABI 绑定（保持共享核心纯 C 契约，不引入 JNI 符号）。
    implementation("net.java.dev.jna:jna:5.17.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.2")
    testImplementation("androidx.arch.core:core-testing:2.2.0")

    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test:core-ktx:1.7.0")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.7.0")
    androidTestImplementation("androidx.room:room-testing:2.8.4")
    androidTestImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.2")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}

tasks.withType<Test>().configureEach {
    finalizedBy("jacocoDebugUnitTestReport")
}

tasks.register<JacocoReport>("jacocoDebugUnitTestReport") {
    dependsOn("testDebugUnitTest")

    reports {
        xml.required.set(true)
        html.required.set(true)
        csv.required.set(false)
    }

    val fileFilter =
        listOf(
            "**/R.class",
            "**/R$*.class",
            "**/BuildConfig.*",
            "**/Manifest*.*",
            "**/*Test*.*",
            "**/*ComposableSingletons*.*",
            "**/MainActivity*.*",
            "**/MainTab*.*",
            "**/RedCodeAppKt*.*",
            "**/*${'$'}DefaultImpls*.*",
            "**/*UiState*.*",
            "**/*FormState*.*",
            "**/*Request*.*",
            "**/*Response*.*",
            "**/data/auth/BackendAuth*.*",
            "**/data/chat/BackendChat*.*",
            "**/data/contacts/BackendFriend*.*",
            "**/data/contacts/BackendUser*.*",
            "**/data/auth/AndroidKeystoreKeyValueStore*.*",
            "**/data/preferences/DataStoreUserPreferenceStore*.*",
            "**/network/APIClient*.*",
            "**/JavaNetHttpTransport*.*",
            "**/HttpTransport*.*",
            "**/realtime/OkHttpWebSocketConnector*.*",
            "**/realtime/WebSocketTransport*.*",
            "**/*Dao*.*",
            "**/*_Impl*.*",
            "**/RedCodeDatabase*.*",
            "**/persistence/*Entity*.*",
            "**/core/model/**",
            "**/di/**",
            "**/ui/theme/**",
        )
    val debugTree =
        fileTree("${layout.buildDirectory.get()}/tmp/kotlin-classes/debug") {
            exclude(fileFilter)
        }
    val mainSrc = "${project.projectDir}/src/main/java"
    sourceDirectories.setFrom(files(mainSrc))
    classDirectories.setFrom(files(debugTree))
    executionData.setFrom(
        fileTree(layout.buildDirectory) {
            include(
                "jacoco/testDebugUnitTest.exec",
                "outputs/unit_test_code_coverage/debugUnitTest/testDebugUnitTest.exec",
            )
        },
    )
}

tasks.register("coverageDebugUnitTest") {
    dependsOn("jacocoDebugUnitTestReport")
}

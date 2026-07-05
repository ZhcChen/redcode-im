plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
    id("com.google.devtools.ksp")
    jacoco
}

android {
    namespace = "com.redcode.im.androidapp"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.redcode.im.androidapp"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
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
    }

    kotlin {
        jvmToolchain(17)
    }

    buildTypes {
        debug {
            enableUnitTestCoverage = true
        }
        release {
            isMinifyEnabled = false
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
    implementation("androidx.room:room-runtime:2.8.4")
    implementation("androidx.room:room-ktx:2.8.4")
    ksp("androidx.room:room-compiler:2.8.4")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.2")
    testImplementation("androidx.arch.core:core-testing:2.2.0")

    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test:core-ktx:1.6.1")
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
            "**/data/auth/AndroidKeystoreKeyValueStore*.*",
            "**/network/APIClient*.*",
            "**/JavaNetHttpTransport*.*",
            "**/HttpTransport*.*",
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

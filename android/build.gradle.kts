group = "com.example.image_picker_master"
version = "1.0-SNAPSHOT"

plugins {
    id("com.android.library")
    // kotlin-android را اینجا اضافه نکن — pub.dev آن را legacy flag می‌کند
}

// KGP را فقط وقتی host آن را نخواسته apply کن.
// builtInKotlin=true  → AGP 9 خودش Kotlin را فراهم می‌کند → apply نکن
// builtInKotlin=false → باید خودمان apply کنیم
val builtInKotlin = providers
    .gradleProperty("android.builtInKotlin")
    .orElse("false")
    .get()
    .trim()
    .equals("true", ignoreCase = true)

if (!builtInKotlin) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

android {
    namespace = "com.example.image_picker_master"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
            res.srcDirs("src/main/res")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

// به‌جای بلاک top-level kotlin{}، از configure استفاده کن
// چون KGP به‌صورت شرطی apply می‌شود و ممکن است در حالت builtInKotlin=true
// اصلاً apply نشده باشد؛ این متد هم با AGP 8 و هم AGP 9 کار می‌کند
project.extensions.configure(
    org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension::class.java
) {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}
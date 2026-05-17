import java.io.File
import java.util.Properties

import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.kulmis.pharmacy.kpms"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.kulmis.pharmacy.kpms"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { rootProject.file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (keystorePropertiesFile.exists()) signingConfigs.getByName("release")
                else signingConfigs.getByName("debug")
            // Keep off until ProGuard keep rules are validated for Supabase / PDF / scanner.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    // Required by flutter_local_notifications (AAR metadata / java.time backport on older APIs).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

// --- KPMS: sync root `.env` into Flutter assets for mobile debug (host file is not readable at runtime) ---
val kpmsRootDir: File = rootProject.projectDir.parentFile

tasks.register("kpmsMergeRootIntoBundledDefaultEnv") {
    group = "kpms"
    description =
        "Writes project-root `.env` into assets/env/default.env before Flutter Release/Profile builds (when `.env` exists)."
    doLast {
        val env = File(kpmsRootDir, ".env")
        val def = File(kpmsRootDir, "assets/env/default.env")
        if (!env.exists()) return@doLast
        def.parentFile.mkdirs()
        val header =
            """
            # Bundled for release/profile — synced from project-root `.env` at Gradle build.
            # Public anon key only. For CI, use `--dart-define` or pre-fill this file in the job.

            """.trimIndent()
        def.writeText(header + env.readText())
    }
}

tasks.register("kpmsSyncDebugGeneratedEnv") {
    group = "kpms"
    description =
        "Copies project-root `.env` to assets/env/generated_debug.env before Flutter Debug builds."
    doLast {
        val out = File(kpmsRootDir, "assets/env/generated_debug.env")
        val src = File(kpmsRootDir, ".env")
        out.parentFile.mkdirs()
        when {
            src.exists() -> src.copyTo(out, overwrite = true)
            !out.exists() ->
                out.writeText(
                    "# KPMS: no root `.env` at Android debug build — add `.env` next to pubspec.yaml.\n",
                )
        }
    }
}

tasks.register("kpmsClearGeneratedDebugEnv") {
    group = "kpms"
    description =
        "Replaces generated_debug.env with a safe placeholder before Flutter Release/Profile builds."
    doLast {
        val out = File(kpmsRootDir, "assets/env/generated_debug.env")
        out.parentFile.mkdirs()
        out.writeText(
            "# KPMS: release/profile — root `.env` is not bundled. Use assets/env/default.env or CI dart-define.\n",
        )
    }
}

afterEvaluate {
    tasks.matching { it.name.startsWith("compileFlutterBuild") && it.name.endsWith("Debug") }
        .configureEach { dependsOn("kpmsSyncDebugGeneratedEnv") }
    tasks.matching {
        val n = it.name
        n.startsWith("compileFlutterBuild") &&
            (n.contains("Release") || n.contains("Profile"))
    }.configureEach {
        dependsOn("kpmsMergeRootIntoBundledDefaultEnv")
        dependsOn("kpmsClearGeneratedDebugEnv")
    }
}

tasks.withType<KotlinCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

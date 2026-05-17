import com.android.build.gradle.BaseExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.dsl.KotlinVersion
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Flutter plugins (e.g. sentry_flutter) may still target Kotlin language 1.6; Kotlin 2.2+ no longer
// supports compiling that dialect — force 1.9+ for every subproject Kotlin compile task.
subprojects {
    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
            languageVersion.set(KotlinVersion.KOTLIN_1_9)
            apiVersion.set(KotlinVersion.KOTLIN_1_9)
        }
    }
}

// Flutter plugins often default to Java 8 — align with :app (17) to avoid obsolete JDK warnings.
subprojects {
    afterEvaluate {
        extensions.findByType<BaseExtension>()?.compileOptions?.apply {
            sourceCompatibility = JavaVersion.VERSION_17
            targetCompatibility = JavaVersion.VERSION_17
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

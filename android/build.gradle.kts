import org.gradle.api.tasks.Copy

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

val appProject = project(":app")

tasks.register<Copy>("copyDebugApkToFlutter") {
    val sourceDir = appProject.layout.buildDirectory.dir("outputs/apk/debug")
    from(sourceDir)
    include("app-debug.apk")

    val flutterOutputDir = rootDir.resolve("../build/app/outputs/flutter-apk")
    into(flutterOutputDir)
}

tasks.matching { it.name == "assembleDebug" }.configureEach {
    finalizedBy(tasks.named("copyDebugApkToFlutter"))
}

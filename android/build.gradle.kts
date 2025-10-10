// android/build.gradle.kts（專案層，不是 app 層）
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

tasks.register<org.gradle.api.tasks.Copy>("copyDebugApkToFlutter") {
    
    from(layout.buildDirectory.dir("outputs/apk/debug"))
    include("app-debug.apk")
  
    into(layout.buildDirectory.dir("outputs/flutter-apk"))
}


tasks.matching { it.name == "assembleDebug" }.configureEach {
    finalizedBy("copyDebugApkToFlutter")
}


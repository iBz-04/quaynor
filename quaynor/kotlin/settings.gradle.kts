pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    plugins {
        id("com.android.library") version "8.7.3"
        id("org.jetbrains.kotlin.android") version "2.0.21"
        id("org.jetbrains.kotlin.jvm") version "2.0.21"
    }
}

plugins {
    id("com.gradleup.nmcp.settings") version "1.4.4"
}

nmcpSettings {
    centralPortal {
        username = System.getenv("MAVEN_CENTRAL_USERNAME")
        password = System.getenv("MAVEN_CENTRAL_PASSWORD")
        publishingType = "AUTOMATIC"
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "quaynor-kotlin"

// :jvm is excluded until the desktop native libraries (Linux, macOS, Windows) are
// built in CI. Without them it packages an empty JAR, and Maven Central releases
// are immutable — publishing it once would permanently burn the coordinate.
// Re-add ":jvm" here when the cross-platform build exists.
include(":common", ":android")
project(":common").name = "quaynor-core"

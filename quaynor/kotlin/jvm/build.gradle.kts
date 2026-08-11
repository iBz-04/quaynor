plugins {
    id("org.jetbrains.kotlin.jvm")
    id("maven-publish")
    signing
}

kotlin {
    jvmToolchain(17)
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}

dependencies {
    api(project(":quaynor-core"))
}

// Native libs are placed in src/main/resources/ following JNA's expected layout:
//   linux-x86-64/libquaynor_uniffi.so
//   linux-aarch64/libquaynor_uniffi.so
//   darwin-x86-64/libquaynor_uniffi.dylib
//   darwin-aarch64/libquaynor_uniffi.dylib
//   win32-x86-64/quaynor_uniffi.dll
// JNA automatically extracts and loads the correct one at runtime.

val sourcesJar by tasks.registering(Jar::class) {
    archiveClassifier.set("sources")
}

val javadocJar by tasks.registering(Jar::class) {
    archiveClassifier.set("javadoc")
}

publishing {
    publications {
        register<MavenPublication>("release") {
            groupId = "ai.quaynor"
            artifactId = "quaynor"
            version = project.version.toString()

            from(components["java"])
            artifact(sourcesJar)
            artifact(javadocJar)
        }
    }
}

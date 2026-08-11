// Root build file — shared configuration for all subprojects
allprojects {
    group = "ai.quaynor"
    version = "0.1.0"
}

// Shared POM metadata and signing for publishable subprojects
subprojects {
    afterEvaluate {
        extensions.findByType<PublishingExtension>()?.apply {
            publications.withType<MavenPublication>().configureEach {
                pom {
                    name.set("Quaynor")
                    description.set("Local LLM inference for Kotlin/Android — chat, tool calling, vision, and embeddings powered by llama.cpp")
                    url.set("https://github.com/iBz-04/quaynor")
                    licenses {
                        license {
                            name.set("MIT")
                            url.set("https://opensource.org/licenses/MIT")
                        }
                    }
                    developers {
                        developer {
                            id.set("quaynor")
                            name.set("Quaynor")
                            email.set("issakaibrahimrayamah@gmail.com")
                        }
                    }
                    scm {
                        connection.set("scm:git:git://github.com/iBz-04/quaynor.git")
                        developerConnection.set("scm:git:ssh://github.com/iBz-04/quaynor.git")
                        url.set("https://github.com/iBz-04/quaynor")
                    }
                }
            }
        }

        // Sign all publications if a signing key is available
        plugins.withId("signing") {
            extensions.findByType<SigningExtension>()?.apply {
                val signingKey = providers.environmentVariable("SIGNING_KEY").orNull
                val signingPassword = providers.environmentVariable("SIGNING_PASSWORD").orNull
                if (signingKey != null) {
                    useInMemoryPgpKeys(signingKey, signingPassword ?: "")
                    sign(extensions.getByType<PublishingExtension>().publications)
                }
            }
        }
    }
}

// Root build file — shared configuration for all subprojects
allprojects {
    group = "site.quaynor"
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

        // Sign all publications if a signing key is available.
        //
        // Two modes:
        //  - SIGNING_KEY set (CI): in-memory armored key, no gpg installed needed.
        //  - SIGNING_USE_GPG_CMD=true (local): delegate to the gpg binary via gpg-agent.
        //
        // The gpg-agent path exists because GnuPG 2.4+ protects exported secret keys with
        // an AEAD scheme that the signing plugin's bundled Bouncy Castle cannot parse,
        // failing with "Could not read PGP secret key". Shelling out to gpg avoids the
        // format entirely rather than re-encrypting the key with weaker settings.
        plugins.withId("signing") {
            extensions.findByType<SigningExtension>()?.apply {
                val signingKey = providers.environmentVariable("SIGNING_KEY").orNull
                val signingPassword = providers.environmentVariable("SIGNING_PASSWORD").orNull
                val useGpgAgent = providers.environmentVariable("SIGNING_USE_GPG_CMD")
                    .orNull?.toBoolean() ?: false

                if (useGpgAgent) {
                    useGpgCmd()
                    sign(extensions.getByType<PublishingExtension>().publications)
                } else if (signingKey != null) {
                    useInMemoryPgpKeys(signingKey, signingPassword ?: "")
                    sign(extensions.getByType<PublishingExtension>().publications)
                }
            }
        }
    }
}

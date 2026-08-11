# Kotlin Build Setup

This document explains how the Kotlin bindings are structured, built, and published.

## Module structure

```
kotlin/
├── build.gradle.kts          # Root: shared version, POM metadata, signing
├── settings.gradle.kts       # Plugin versions, nmcp config, project rename
├── common/                   # All Kotlin source code
│   ├── build.gradle.kts      # kotlin("jvm"), maven-publish, signing
│   ├── src/                  # Wrapper classes (Chat, Model, Tool, etc.)
│   ├── generated/            # UniFFI-generated bindings
│   └── test/                 # Unit + integration tests
├── android/                  # Android packaging
│   ├── build.gradle.kts      # com.android.library, maven-publish, signing
│   └── src/main/AndroidManifest.xml
└── jvm/                      # Desktop JVM packaging
    └── build.gradle.kts      # kotlin("jvm"), maven-publish, signing
```

### Why three modules?

The Kotlin wrapper code is identical across platforms. What differs is how the native library (`libquaynor_uniffi`) is packaged:

- **Android** needs the native `.so` in `jniLibs/{arm64-v8a,x86_64}/` inside an AAR, and JNA must be the AAR variant (`jna:5.14.0@aar`).
- **Desktop JVM** needs native libs for all platforms in `src/main/resources/` following JNA's naming convention (`linux-x86-64/`, `darwin-aarch64/`, `win32-x86-64/`), inside a regular JAR with JNA as a normal JAR dependency.

A single module can't produce both an AAR and a JAR, so we split into three:

- **`:common`** (published as `quaynor-core`) — contains all Kotlin code. Pure JVM, no Android dependency. This is where compilation and tests happen.
- **`:android`** — empty shell that depends on `:common`, applies the Android Gradle plugin, and packages the AAR with Android-specific JNI libs.
- **`:jvm`** — empty shell that depends on `:common`, packages a JAR with desktop native libs in JNA layout.

## Published artifacts

Three artifacts are published to Maven Central:

| Artifact | Type | Contains |
|---|---|---|
| `site.quaynor:quaynor-core` | JAR | Kotlin wrappers + generated UniFFI bindings (~100KB) |
| `site.quaynor:quaynor-android` | AAR | Android native libs (arm64-v8a, x86_64), depends on `quaynor-core` |
| `site.quaynor:quaynor` | JAR | Desktop native libs (Linux, macOS, Windows), depends on `quaynor-core` |

Consumers add one dependency:

```kotlin
// Android
implementation("site.quaynor:quaynor-android:0.1.0")

// Desktop JVM
implementation("site.quaynor:quaynor:0.1.0")
```

Gradle automatically pulls `quaynor-core` as a transitive dependency.

## The project rename

The `:common` directory is named `common/` on disk, but the Gradle project is renamed in `settings.gradle.kts`:

```kotlin
project(":common").name = "quaynor-core"
```

This matters because when Gradle publishes `:jvm` or `:android`, their POM files reference dependencies by Gradle project name. Without the rename, the POM would say `<artifactId>common</artifactId>`, which is a poor name for a Maven Central artifact. With the rename, it correctly says `<artifactId>quaynor-core</artifactId>`.

After the rename, other modules reference it as `project(":quaynor-core")` instead of `project(":common")`.

## JNA conflict

JNA ships as two artifacts with identical Java classes:
- `jna:5.14.0` (JAR) — for desktop JVM, includes native libs for all desktop platforms
- `jna:5.14.0@aar` (AAR) — for Android, includes the Android JNI native lib

`:common` uses `implementation("net.java.dev.jna:jna:5.14.0")` (the JAR). This is correct for desktop JVM and for compilation. But on Android, both the JAR and AAR would end up on the classpath, causing duplicate class errors.

The `:android` module solves this with an exclude:

```kotlin
api(project(":quaynor-core")) {
    exclude(group = "net.java.dev.jna")  // Remove JNA JAR from core's transitive deps
}
implementation("net.java.dev.jna:jna:5.14.0@aar")  // Provide JNA AAR instead
```

This exclude also works for the published artifact — when a consumer depends on `quaynor-android`, Gradle excludes JNA from `quaynor-core`'s transitive dependencies and uses the AAR variant from the Android module.

## Maven Central publishing

Publishing uses [nmcp](https://github.com/GradleUp/nmcp) (New Maven Central Publishing), a Gradle settings plugin that handles the Central Portal upload API.

```kotlin
// settings.gradle.kts
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
```

The `publishAggregationToCentralPortal` task collects all three publications, signs them, and uploads them as a single atomic deployment bundle. Maven Central validates them together — all succeed or all fail.

POM metadata (name, description, license, developers, SCM) is configured once in the root `build.gradle.kts` and applied to all subprojects via `afterEvaluate`.

### Required environment variables for publishing

| Variable | Purpose |
|---|---|
| `MAVEN_CENTRAL_USERNAME` | Central Portal API token username |
| `MAVEN_CENTRAL_PASSWORD` | Central Portal API token password |
| `SIGNING_KEY` | ASCII-armored GPG private key (CI signing) |
| `SIGNING_PASSWORD` | GPG key passphrase |
| `SIGNING_USE_GPG_CMD` | `true` to sign via the local `gpg` binary instead (local releases) |

Never put these in a `gradle.properties` inside the repo — that file is committed. Use
environment variables, or `~/.gradle/gradle.properties` in your home directory.

### Publishing the public key to a keyserver

**Required, and the single most common cause of a failed deployment.** Central verifies
each `.asc` by looking your public key up on a keyserver. Valid signatures from a key it
cannot find are rejected with:

```
Invalid signature for file: ...asc - Could not find a public key by the key fingerprint.
```

Upload to **both** supported keyservers. Central's validator queries `keys.openpgp.org`,
so uploading only to `keyserver.ubuntu.com` is not enough:

```bash
gpg --keyserver hkps://keys.openpgp.org --send-keys <FINGERPRINT>
gpg --keyserver hkps://keyserver.ubuntu.com --send-keys <FINGERPRINT>
```

Use the `hkps://` scheme explicitly. The bare hostname resolves to `hkp://` on port 11371,
which many networks block — and `gpg` prints `sending key ...` regardless, so a blocked
upload looks identical to a successful one. Always verify the key is actually retrievable
before publishing:

```bash
curl -s -o /dev/null -w "%{http_code}\n" \
  "https://keys.openpgp.org/vks/v1/by-fingerprint/<FINGERPRINT>"
```

`200` means Central will find it. No email verification is needed — `keys.openpgp.org`
withholds identity information until an address is confirmed, but serves key material by
fingerprint immediately. Note that Central caches keyserver lookups, so after a failed
attempt allow ~30 minutes before retrying rather than re-uploading the key.

### Signing locally vs in CI

GnuPG 2.4+ protects exported secret keys with an AEAD scheme the signing plugin's bundled
Bouncy Castle cannot parse, so `SIGNING_KEY` fails with `Could not read PGP secret key`.
For local releases, delegate to the `gpg` binary instead:

```bash
export SIGNING_USE_GPG_CMD=true
export GPG_TTY=$(tty)          # otherwise pinentry fails: "Inappropriate ioctl for device"
echo test | gpg --clearsign > /dev/null   # caches the passphrase in gpg-agent
```

The last step matters: the Gradle daemon has no controlling terminal and can never prompt
for a passphrase, so it must already be cached (default TTL 10 minutes). Installing
`pinentry-mac` and pointing `~/.gnupg/gpg-agent.conf` at it gives a GUI prompt that works
from any process, making the cache-warming step unnecessary.

`signing.gnupg.executable=gpg` is set in `gradle.properties` because Gradle otherwise
looks for `gpg2`, which Homebrew's gnupg does not install.

### Testing locally

Publish to the local Maven repository (no credentials needed):

```bash
./gradlew publishToMavenLocal
```

Artifacts go to `~/.m2/repository/site/quaynor/`. Inspect the POMs to verify dependencies and metadata.

### Release checklist

Maven Central releases are **immutable** — a version number cannot be reused once
published, so verify locally first. (A deployment rejected during *validation* is not a
release; that version is still available.)

1. Stage the Android native libraries. This must come after any `clean`, because the
   `:android` module reads `jniLibs` from its own build directory:

   ```bash
   ./Scripts/build-android-libs.sh release
   ```

2. Publish locally and confirm what was actually produced:

   ```bash
   ./gradlew publishToMavenLocal
   ```

   - Both ABIs are inside the AAR — an AAR with no native libraries is the worst
     failure mode, since it installs and then fails at runtime:

     ```bash
     unzip -l ~/.m2/repository/site/quaynor/quaynor-android/*/quaynor-android-*.aar | grep '\.so'
     ```

   - Every artifact is signed (expect one `.asc` per file, 10 in total):

     ```bash
     find ~/.m2/repository/site/quaynor -name '*.asc' | wc -l
     ```

   - Each artifact has both a sources and a javadoc jar. Central rejects deployments
     missing either; `:android` has no sources of its own, so it publishes empty ones.

3. Confirm the signing key is on the keyservers (see above) — do this before uploading,
   not after a rejection, because Central caches negative lookups.

4. Publish. **Do not run `clean` first**, or the staged native libraries are deleted and
   an empty AAR is published:

   ```bash
   ./gradlew publishAggregationToCentralPortal
   ```

`publishingType = "AUTOMATIC"` means a successful validation releases immediately with no
confirmation step in the portal. Artifacts take a few minutes to validate and up to ~30
minutes to appear on `repo1.maven.org`.

## Version management

The version is set once in the root `build.gradle.kts`:

```kotlin
allprojects {
    version = "0.1.0"
}
```

All three artifacts share the same version. The CI release job also passes `-Pversion=X.Y.Z` from the git tag, though currently the hardcoded version must match.

# Swift Manual Release

This document defines a fully manual release process for the Swift binding. Nothing here auto-publishes.

## Scope

This flow prepares Apple native artifacts for Swift consumption:

- `QuaynorFFI.xcframework.zip` built from `quaynor-uniffi`
- checksum for Swift Package Manager binary artifacts
- a predictable GitHub release tag and upload process

## Prerequisites

- macOS with Xcode command line tools
- Rust toolchain with Apple targets
- `swift`, `cargo`, `xcodebuild`, `zip`
- write access to `https://github.com/iBz-04/quaynor`

## One release, step by step

From the repo root:

```bash
cd quaynor
swift/Scripts/release-xcframework.sh <version>
```

Example:

```bash
swift/Scripts/release-xcframework.sh 0.1.0
```

The script performs:

1. Release builds for:
   - `aarch64-apple-ios`
   - `aarch64-apple-ios-sim`
   - `x86_64-apple-ios`
   - `aarch64-apple-darwin`
   - `x86_64-apple-darwin`
2. Creates universal iOS simulator and macOS static archives with `lipo`
3. Creates `QuaynorFFI.xcframework`
4. Creates `QuaynorFFI.xcframework.zip`
5. Prints `swift package compute-checksum` output and suggested tag

Output location:

`quaynor/target/swift-release/artifacts/`

## Publish on GitHub Releases

1. Create a GitHub release tag: `quaynor-swift-<version>`
2. Upload:
   - `QuaynorFFI.xcframework.zip`
3. Keep release notes explicit about supported platforms and version

## Wire checksum into Swift package

After upload, use the artifact URL and checksum to update Swift package distribution metadata in your release branch.

If you move the package to SPM binary distribution, use:

- `binaryTarget(name:url:checksum:)`
- the checksum printed by the script
- the uploaded release asset URL

## Verification checklist

Before announcing a release:

1. Download artifact from the new GitHub release
2. Recompute checksum and compare
3. Build a clean sample app that imports Quaynor
4. Run a basic model load + chat call on macOS and iOS simulator

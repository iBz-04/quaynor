# Quaynor Swift

The distributed Swift package for Quaynor lives at the repository root so users can install it directly from GitHub in Swift Package Manager. This directory contains the generated FFI layer, wrapper sources, and release tooling that back that package.

- Rust and UniFFI define the ABI layer.
- Generated `Rust*` Swift bindings live in `Sources/QuaynorFFI`.
- The public Swift API lives in `Sources/Quaynor` and exposes `Model`, `Chat`, `TokenStream`, `Tool`, `Prompt`, `Encoder`, and `CrossEncoder`.

## Layout

- `Sources/CQuaynorFFI`: generated C header and module map
- `Sources/QuaynorFFI`: generated UniFFI Swift bindings
- `Sources/Quaynor`: handwritten Swift wrapper layer
- `../../Package.swift`: root Swift Package Manager manifest used for distribution
- `Scripts/generate-bindings.sh`: regenerate the committed Swift FFI sources after Rust interface changes
- `Scripts/release-xcframework.sh`: build Apple release artifacts manually
- `RELEASING.md`: manual Swift release playbook

## Regenerating bindings

From the `quaynor/` workspace root:

```bash
swift/Scripts/generate-bindings.sh
```

The script:

1. builds `quaynor-uniffi`
2. runs UniFFI Swift code generation
3. refreshes the committed files in `swift/Sources/CQuaynorFFI` and `swift/Sources/QuaynorFFI`

## Distribution

Consumers install Quaynor from the repository root:

```swift
dependencies: [
    .package(url: "https://github.com/iBz-04/quaynor.git", from: "0.1.0")
]
```

The root package downloads `QuaynorFFI.xcframework.zip` from the matching GitHub release and exposes the Swift wrapper API on top.

SwiftPM resolves versions from semver Git tags. The binary artifact itself is fetched from the separate GitHub release tag referenced in the root `Package.swift`.

## Building locally

To validate the distributed package from this checkout:

```bash
cd ..
swift build
```

For binding regeneration work, rebuild the Rust UniFFI library first:

```bash
cargo build -p quaynor-uniffi
swift/Scripts/generate-bindings.sh
```

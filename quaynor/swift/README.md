# Quaynor Swift

This package is the start of a native Swift binding for Quaynor. It currently supports macOS source checkouts and follows the same split already used by the existing React Native binding:

- Rust and UniFFI define the ABI layer.
- Generated `Rust*` Swift bindings live in `Sources/QuaynorFFI`.
- The public Swift API lives in `Sources/Quaynor` and exposes `Model`, `Chat`, `TokenStream`, `Tool`, `Prompt`, `Encoder`, and `CrossEncoder`.

## Layout

- `Sources/CQuaynorFFI`: generated C header and module map
- `Sources/QuaynorFFI`: generated UniFFI Swift bindings
- `Sources/Quaynor`: handwritten Swift wrapper layer
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

## Building locally

Build the Rust UniFFI library before building or consuming the Swift package:

```bash
cd quaynor
cargo build -p quaynor-uniffi
cd swift
swift build
```

The Swift package links against `../target/debug/libquaynor_uniffi.dylib` for local macOS development. If a release build has already been produced, `../target/release` is also added to the linker search path.

## Scope of this scaffold

This scaffold focuses on the binding surface and wrapper ergonomics. It includes a manual XCFramework release script, but the package itself is still source-first for local macOS development until binary target distribution is wired into `Package.swift`.

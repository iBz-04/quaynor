---
description: How to set up the Quaynor Swift package for local macOS development
---

# Getting started with Swift

Quaynor's Swift binding is currently a source-based package for macOS development. It reuses the existing UniFFI layer, so the Swift package depends on the Rust `quaynor-uniffi` library being built locally first.

## Build order

```sh
cd quaynor
cargo build -p quaynor-uniffi
cd swift
swift build
```

## What this is for

- Import `Quaynor` from another local Swift package or Xcode project on macOS.
- Use the wrapper API in `Sources/Quaynor` for `Model`, `Chat`, `TokenStream`, `Encoder`, `CrossEncoder`, `SamplerPresets`, `Prompt`, and `Tool`.
- Regenerate the committed UniFFI sources with `swift/Scripts/generate-bindings.sh` after Rust API changes.

## What it is not yet

- It is not yet packaged as an XCFramework.
- It is not yet a published binary Swift package.
- It is not yet wired for iOS distribution.

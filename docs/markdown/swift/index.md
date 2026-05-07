---
description: How to install the Quaynor Swift package through Swift Package Manager
---

# Getting started with Swift

Quaynor's Swift binding is distributed through Swift Package Manager for iOS and macOS. Swift Package Manager, usually shortened to SwiftPM, is Apple's package manager for Swift and Xcode projects. The package downloads the published `QuaynorFFI.xcframework` from GitHub Releases, so consumers do not need a local Rust toolchain.

## Install

Add the package in Xcode with:

- URL: `https://github.com/iBz-04/quaynor.git`
- Dependency rule: `Up to Next Major Version`
- Version: `0.1.0`

Or declare it in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/iBz-04/quaynor.git", from: "0.1.0")
]
```

This install flow depends on a real semver Git tag like `0.1.0`. SwiftPM resolves package versions from Git tags, not from release asset tags.

## Use it

The package exposes:

- `Model`
- `Chat`
- `TokenStream`
- `Encoder`
- `CrossEncoder`
- `SamplerPresets`
- `Prompt`
- `Tool`

That means Swift supports chat, streaming, embeddings, reranking, and tool calling through the wrapper API.

Example:

```swift
import Quaynor

let model = try await Model.fromPath(
    path: "huggingface:bartowski/Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf"
)
let chat = Chat(model: model)
let answer = try await chat.ask("Is a zebra black or white?").completed()
print(answer)
```

## Release workflow

For manual release control, use:

- `quaynor/swift/Scripts/release-xcframework.sh`
- `quaynor/swift/RELEASING.md`

For each public Swift release, publish all of these:

- a semver Git tag such as `0.1.0`
- a GitHub release tag such as `quaynor-swift-0.1.0`
- the `QuaynorFFI.xcframework.zip` asset attached to that GitHub release

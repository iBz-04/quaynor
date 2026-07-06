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
- `CachedModel`
- `ChatStats`

That means Swift supports model loading and downloads, chat, streaming, embeddings, reranking, tokenization, chat stats, cache inspection, and tool calling through the wrapper API.

Example:

```swift
import Quaynor

let model = try await Model.load(
    modelPath: "hf://bartowski/Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf"
)
let chat = Chat(model: model)
let answer = try await chat.ask("Is a zebra black or white?").completed()
print(answer)
```

Download progress and cache inspection are available directly on `Model`:

```swift
let localPath = try await Model.downloadModel(
    modelPath: "hf://bartowski/Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf"
) { downloaded, total in
    print("\(downloaded) / \(total)")
}

let cachedModels = try Model.getCachedModels()
print(localPath)
print(cachedModels)
```

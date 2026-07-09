---
description: How to install the Quaynor Swift package through Swift Package Manager
---

# Getting started with Swift

Quaynor's Swift binding is distributed through Swift Package Manager for iOS and macOS. Swift Package Manager, usually shortened to SwiftPM, is Apple's package manager for Swift and Xcode projects. The package downloads the published `QuaynorFFI.xcframework` from GitHub Releases, so consumers do not need a local Rust toolchain.

## Install

Add the package in Xcode with:

- URL: `https://github.com/iBz-04/quaynor.git`
- Dependency rule: `Up to Next Major Version`
- Version: `0.1.2`

Or declare it in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/iBz-04/quaynor.git", from: "0.1.2")
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

That means Swift supports model loading and downloads, chat, streaming, embeddings, reranking, tokenization, chat stats, cache inspection, cache deletion, and tool calling through the wrapper API.

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

Download progress, cache inspection, and cache deletion are available directly on `Model`:

```swift
let localPath = try await Model.downloadModel(
    modelPath: "hf://bartowski/Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf"
) { downloaded, total in
    print("\(downloaded) / \(total)")
}

let cachedModels = try Model.getCachedModels()
for model in cachedModels {
    print("\(model.path) (\(model.size) bytes)")
}

let deletedBytes = try Model.deleteCachedModel(modelPath: cachedModels[0].path)
print("Deleted \(deletedBytes) bytes")
print(localPath)
```

`deleteCachedModel` only accepts paths inside Quaynor's model cache. It returns the number of bytes removed and throws if the path is outside the cache or the model is still loaded.

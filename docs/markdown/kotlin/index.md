---
description: How to install the Quaynor Kotlin package for Android and use it from Kotlin
---

# Getting started with Kotlin

Quaynor's Kotlin binding is published to Maven Central and loads the native engine through [JNA](https://github.com/java-native-access/jna), so consumers do not need a local Rust toolchain. The Android artifact ships prebuilt native libraries for `arm64-v8a` and `x86_64`.

## Install

Add the dependency to your module's `build.gradle.kts`:

```kotlin
dependencies {
    implementation("site.quaynor:quaynor-android:0.1.0")
}
```

Gradle resolves `site.quaynor:quaynor-core` transitively — that is where the Kotlin API lives. You do not need to declare it yourself.

Requirements:

- `minSdk` 26 or higher
- Java 11 bytecode target
- Supported ABIs: `arm64-v8a`, `x86_64`

!!! info ""
    A desktop JVM artifact (Linux, macOS, Windows) is not published yet. On the JVM you can build it locally from [`quaynor/kotlin/`](https://github.com/iBz-04/quaynor/tree/main/quaynor/kotlin) in the meantime.

## Use it

The package exposes:

- `Model`
- `Chat`
- `TokenStream`
- `Encoder`
- `CrossEncoder`
- `Prompt`
- `Tool`
- `SamplerPresets` and `buildSampler`
- `Message`
- `CachedModel`
- `ChatStats`

That covers model loading and downloads, chat, streaming, embeddings, reranking, tokenization, chat stats, cache inspection, cache deletion, and tool calling.

Everything that touches the model is a `suspend` function, so call it from a coroutine:

```kotlin
import ai.quaynor.Chat
import ai.quaynor.Model

val model = Model.load("hf://bartowski/Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf")
val chat = Chat(model = model)
val answer = chat.ask("Is a zebra black or white?").completed()
println(answer)
```

Note that the public API lives in the `ai.quaynor` package. The generated bindings under `uniffi.quaynor` are an implementation detail and should not be imported directly.

## Downloads and the model cache

`Model.download` fetches a model and returns its local path, which is useful when you need custom headers for gated repositories:

```kotlin
val localPath = Model.download(
    modelPath = "hf://bartowski/Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf",
    headers = mapOf("Authorization" to "Bearer $token")
) { downloaded, total ->
    println("$downloaded / $total")
}
println(localPath)
```

For unauthenticated downloads you can pass the URL straight to `Model.load`.

Inspect and prune the cache with the top-level helpers:

```kotlin
import ai.quaynor.deleteCachedModel
import ai.quaynor.getCachedModels

val cached = getCachedModels()
for (model in cached) {
    println("${model.path} (${model.size} bytes)")
}

val freedBytes = deleteCachedModel(cached.first().path)
println("Deleted $freedBytes bytes")
```

`deleteCachedModel` only accepts paths inside Quaynor's model cache. It returns the number of bytes removed and throws if the path is outside the cache or the model is still loaded.

## Releasing resources

`Model`, `Chat`, `Encoder`, `CrossEncoder`, and `TokenStream` all hold native resources and implement `Closeable`. Use `use` so they are freed even if something throws:

```kotlin
Model.load("/path/to/model.gguf").use { model ->
    Chat(model = model).use { chat ->
        println(chat.ask("Hello!").completed())
    }
}
```

On Android, a long-lived `Chat` typically belongs to a `ViewModel` and should be closed in `onCleared()`.

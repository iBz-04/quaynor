---
title: Logging & Troubleshooting
description: Read Quaynor's native logs from Kotlin and fix the most common failures.
sidebar_title: Logging & Troubleshooting
order: 6
---

Most of Quaynor's work happens in native code, so when something goes wrong the useful detail is in the native log rather than in the Kotlin stack trace.

## Reading the logs on Android

Logging initializes automatically the first time you load a model — there is nothing to enable. Native output is written to logcat under the tag `quaynor` at `DEBUG` level and above.

```sh
adb logcat -s quaynor
```

Inside Android Studio, type `tag:quaynor` in the Logcat filter box. The first line you should see is:

```
Quaynor logging initialized
```

If that line never appears, the native library was never reached — the model load failed earlier than you think, or the library did not load at all. Skip to [UnsatisfiedLinkError](#unsatisfiedlinkerror) below.

Model loading logs the path, GPU flag, and projection model it was given, which is usually enough to spot a wrong path or a silently disabled GPU:

```
load_model called: path=/data/.../model.gguf, gpu=true, mmproj=None
load_model SUCCESS for /data/.../model.gguf
```

!!! info ""
    Logging is Android-only. On the desktop JVM the native logger is a no-op, and llama.cpp writes its own diagnostics to standard error instead.

## Handling errors

Every failure surfaces as `QuaynorException.Exception`, carrying the native message as its text. It is a flat error type — there are no variants to branch on — so match on the exception and read the message:

```kotlin
import uniffi.quaynor.QuaynorException

try {
    val model = Model.load("/path/to/model.gguf")
} catch (e: QuaynorException) {
    Log.e("MyApp", "Model load failed: ${e.message}")
}
```

This is the one place where importing from `uniffi.quaynor` is expected, since the exception type is generated rather than wrapped.

Errors are wrapped with context on the way out, so a load failure reads as `Failed to load model '<path>': <cause>` rather than a bare message.

## UnsatisfiedLinkError

A `java.lang.UnsatisfiedLinkError` means JNA could not find or load `libquaynor_uniffi`. The usual causes:

**An unsupported ABI.** The published AAR ships `arm64-v8a` and `x86_64` only. There is no `armeabi-v7a` build, so 32-bit ARM devices and some older emulator images will fail. Check what your build is filtering to:

```kotlin
android {
    defaultConfig {
        ndk {
            abiFilters += listOf("arm64-v8a", "x86_64")
        }
    }
}
```

Use an `arm64-v8a` emulator image on Apple silicon and `x86_64` on Intel hosts.

**The native library was stripped from the APK.** If you use `packagingOptions` or a shrinker that excludes `**/*.so`, the library is gone at runtime even though it was present at build time. Confirm what shipped:

```sh
unzip -l app-release.apk | grep quaynor
```

**On the desktop JVM, the library isn't on JNA's path.** Point `jna.library.path` at the directory containing the built library:

```sh
java -Djna.library.path=/path/to/target/release -jar app.jar
```

When running the package's own tests, the `QUAYNOR_LIB_DIR` environment variable does this for you.

## Common runtime failures

**Out of memory when loading a model.** Mobile devices have far less usable memory than a laptop, and llama.cpp needs the whole model resident. Prefer a smaller quantization — a 0.6B Q4\_K\_M model is a reasonable starting point on a phone — and check the model against the device before loading rather than after.

**Context size larger than the model supports.** Setting `contextSize` above the model's trained maximum fails at load. Read the ceiling from the model:

```kotlin
val model = Model.load("/path/to/model.gguf")
val chat = Chat(model = model, contextSize = minOf(4096u, model.maxCtx))
```

**`IllegalArgumentException` when constructing a `Tool`.** Either the function does not return `String`, or a parameter uses an unsupported type. This throws when the `Tool` is created, not when the model calls it, so it fails fast in development. See [Tool Calling](tool-calling.md) for the supported types and the local-function restriction.

**A tool never gets called.** Not all models tool-call reliably. Verify the schema the model is shown with `tool.getSchemaJson()`, and confirm the tool actually ran by inspecting the history:

```kotlin
val called = chat.getChatHistory().filterIsInstance<Message.Tool>()
println("tool invocations: ${called.size}")
```

**`IllegalStateException: A terminal step was already called.`** A `buildSampler` block called two terminal steps. Use exactly one of `dist`, `greedy`, `mirostatV1`, or `mirostatV2` — or none, which defaults to `dist()`.

## Resource leaks

`Model`, `Chat`, `Encoder`, `CrossEncoder`, and `TokenStream` hold native memory that the JVM garbage collector does not manage. Leaking a `Model` leaks the entire weights allocation. Use `use` for scoped work, and tie longer-lived instances to a lifecycle:

```kotlin
class ChatViewModel : ViewModel() {
    private var chat: Chat? = null

    override fun onCleared() {
        chat?.close()
        chat = null
    }
}
```

Calling a method on an instance after `close()` fails at the native boundary, so close it once at the end of its lifetime rather than after each request.

## Slow generation

- Confirm the GPU is actually in use — the `gpu=true` flag in the load log reflects what you requested, not what the backend achieved. Watch for llama.cpp backend lines in logcat around load time.
- A debug build of the native library is dramatically slower than a release build. Ship release.
- Sustained generation will thermally throttle a phone. Benchmark over a minute or more rather than a single short prompt.

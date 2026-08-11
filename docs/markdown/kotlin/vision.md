---
title: Vision & Hearing
description: Use image and audio inputs from Kotlin with multimodal models.
sidebar_title: Vision & Hearing
order: 3
---

Kotlin supports multimodal prompts through `Prompt`, as long as the model and projection model were trained to work together.

## Choosing a model

For image or audio input you usually need:

1. a multimodal GGUF model
2. a matching projection model, often named with `mmproj`

Load both by passing `projectionModelPath`:

```kotlin
import ai.quaynor.Chat
import ai.quaynor.Model

val model = Model.load(
    modelPath = "/path/to/multimodal-model.gguf",
    projectionModelPath = "/path/to/mmproj.gguf"
)
val chat = Chat(
    model = model,
    systemPrompt = "You can understand text, images, and audio."
)
```

You can also do this directly through `Chat.fromPath`.

## Building a multimodal prompt

Use `Prompt` parts for text, image, and audio:

```kotlin
import ai.quaynor.Prompt

val prompt = Prompt(
    Prompt.Text("Describe what you see and hear."),
    Prompt.Image("/path/to/dog.png"),
    Prompt.Audio("/path/to/sound.mp3")
)

val answer = chat.ask(prompt).completed()
println(answer)
```

Multimodal prompts stream like any other, so you can show tokens as they arrive:

```kotlin
chat.ask(prompt).asFlow().collect { print(it) }
```

## Working with images on Android

Asset paths are read from the filesystem, so content from a photo picker or camera intent needs to be a real file first. Copy the `Uri` into your cache directory and pass that path:

```kotlin
val file = File(context.cacheDir, "input.png")
context.contentResolver.openInputStream(uri)?.use { input ->
    file.outputStream().use { output -> input.copyTo(output) }
}

val answer = chat.ask(
    Prompt(
        Prompt.Text("What is in this picture?"),
        Prompt.Image(file.absolutePath)
    )
).completed()
```

## Tips

- The model and projection model must match. Mixing arbitrary GGUF and `mmproj` files will usually fail or behave badly.
- Prompt order matters. Try alternating text and assets if results are weak.
- Some multimodal models consume a lot of context per image or audio segment, so increase `contextSize` when needed.

Example with a larger context window:

```kotlin
val chat = Chat.fromPath(
    modelPath = "/path/to/multimodal-model.gguf",
    projectionModelPath = "/path/to/mmproj.gguf",
    contextSize = 8192u
)
```

Vision models are also considerably larger than their text-only counterparts, which matters more on a phone than on a desktop. Check the device's available memory before loading one, and prefer a smaller quantization on mobile.

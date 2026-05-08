---
title: Vision & Hearing
description: Use image and audio inputs from Swift with multimodal models.
sidebar_title: Vision & Hearing
order: 3
---

Swift supports multimodal prompts through `Prompt`, as long as the model and projection model were trained to work together.

## Choosing a model

For image or audio input you usually need:

1. a multimodal GGUF model
2. a matching projection model, often named with `mmproj`

Load both by passing `projectionModelPath`:

```swift
import Quaynor

let model = try await Model.load(
    modelPath: "/path/to/multimodal-model.gguf",
    projectionModelPath: "/path/to/mmproj.gguf"
)
let chat = try Chat(
    model: model,
    systemPrompt: "You can understand text, images, and audio."
)
```

You can also do this directly through `Chat.fromPath`.

## Building a multimodal prompt

Use `Prompt` parts for text, image, and audio:

```swift
let prompt = Prompt(parts: [
    Prompt.text("Describe what you see and hear."),
    Prompt.image("/path/to/dog.png"),
    Prompt.audio("/path/to/sound.mp3")
])

let answer = try await chat.ask(prompt).completed()
print(answer)
```

## Tips

- The model and projection model must match. Mixing arbitrary GGUF and `mmproj` files will usually fail or behave badly.
- Prompt order matters. Try alternating text and assets if results are weak.
- Some multimodal models consume a lot of context per image or audio segment, so increase `contextSize` when needed.

Example with a larger context window:

```swift
let chat = try await Chat.fromPath(
    modelPath: "/path/to/multimodal-model.gguf",
    projectionModelPath: "/path/to/mmproj.gguf",
    contextSize: 8192
)
```

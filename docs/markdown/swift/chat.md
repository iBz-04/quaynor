---
title: Chat
description: Chat sessions, streaming responses, history, and context management in Swift.
sidebar_title: Chat
order: 1
---

Every interaction with a chat model starts by creating a `Chat`.

## Creating a Chat

The simplest entrypoint is `Chat.fromPath`:

```swift
import Quaynor

let chat = try await Chat.fromPath(
    modelPath: "huggingface:bartowski/Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf"
)
```

If you want to share one loaded model across multiple chat sessions, load the `Model` first:

```swift
import Quaynor

let model = try await Model.load(
    modelPath: "huggingface:bartowski/Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf"
)
let chat1 = try Chat(model: model)
let chat2 = try Chat(model: model)
```

## Asking and streaming

`chat.ask` returns a `TokenStream`.

```swift
let stream = try chat.ask("Why is the sky blue?")
```

To wait for the full answer:

```swift
let full = try await stream.completed()
print(full)
```

To stream tokens as they arrive:

```swift
for try await token in stream {
    print(token, terminator: "")
}
```

## Chat history

Quaynor keeps the conversation history inside the `Chat` instance.

Read it:

```swift
let messages = try await chat.getChatHistory()
print(messages.count)
```

Replace it:

```swift
try await chat.setChatHistory([
    .message(role: .system, content: "You are concise."),
    .message(role: .user, content: "Summarize the task.")
])
```

## System prompt and context

Set the system prompt when creating the chat:

```swift
let chat = try await Chat.fromPath(
    modelPath: "/path/to/model.gguf",
    systemPrompt: "You are a precise engineering assistant.",
    contextSize: 4096
)
```

Reset the current context while optionally changing defaults:

```swift
try await chat.resetContext(systemPrompt: "You are a code reviewer.")
```

Or just clear the accumulated history:

```swift
try await chat.resetHistory()
```

## Template variables

Some models expose extra chat-template switches such as reasoning toggles.

```swift
let chat = try await Chat.fromPath(
    modelPath: "/path/to/model.gguf",
    templateVariables: ["enable_thinking": true]
)
```

Update them later:

```swift
try await chat.setTemplateVariable(name: "enable_thinking", value: false)
let variables = try await chat.getTemplateVariables()
print(variables)
```

## GPU

GPU acceleration is enabled by default. Disable it with `useGpu: false` when needed:

```swift
let model = try await Model.load(
    modelPath: "/path/to/model.gguf",
    useGpu: false
)
```

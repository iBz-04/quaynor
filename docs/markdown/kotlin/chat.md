---
title: Chat
description: Chat sessions, streaming responses, history, and context management in Kotlin.
sidebar_title: Chat
order: 1
---

Every interaction with a chat model starts by creating a `Chat`.

## Creating a Chat

The simplest entrypoint is `Chat.fromPath`:

```kotlin
import ai.quaynor.Chat

val chat = Chat.fromPath(
    modelPath = "hf://bartowski/Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf"
)
```

If you want to share one loaded model across multiple chat sessions, load the `Model` first:

```kotlin
import ai.quaynor.Chat
import ai.quaynor.Model

val model = Model.load("hf://bartowski/Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf")
val chat1 = Chat(model = model)
val chat2 = Chat(model = model)
```

Loading a model is expensive in both time and memory, so sharing one `Model` across sessions is usually what you want.

When loading a remote model, pass a progress callback:

```kotlin
val model = Model.load(
    modelPath = "hf://bartowski/Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf"
) { downloaded, total ->
    println("$downloaded / $total")
}
```

## Asking and streaming

`chat.ask` returns a `TokenStream`.

```kotlin
val stream = chat.ask("Why is the sky blue?")
```

To wait for the full answer:

```kotlin
val full = stream.completed()
println(full)
```

To stream tokens as they arrive, collect the `Flow`:

```kotlin
import kotlinx.coroutines.flow.collect

chat.ask("Why is the sky blue?").asFlow().collect { token ->
    print(token)
}
```

`asFlow()` is cancellation-aware — cancelling the collecting coroutine stops the stream. You can also pull tokens manually, where `nextToken()` returns `null` once generation ends:

```kotlin
val stream = chat.ask("Count to three.")
while (true) {
    val token = stream.nextToken() ?: break
    print(token)
}
```

To stop generation early from elsewhere:

```kotlin
chat.stopGeneration()
```

## Chat history

Quaynor keeps the conversation history inside the `Chat` instance.

Read it:

```kotlin
val messages = chat.getChatHistory()
println(messages.size)
```

`Message` is a sealed class, so you can branch on the variants exhaustively:

```kotlin
import ai.quaynor.Message

for (message in chat.getChatHistory()) {
    when (message) {
        is Message.User -> println("user: ${message.content}")
        is Message.Assistant -> println("assistant: ${message.content}")
        is Message.System -> println("system: ${message.content}")
        is Message.Tool -> println("tool ${message.name}: ${message.content}")
    }
}
```

Replace it:

```kotlin
chat.setChatHistory(
    listOf(
        Message.System("You are concise."),
        Message.User("Summarize the task.")
    )
)
```

## System prompt and context

Set the system prompt when creating the chat:

```kotlin
val chat = Chat.fromPath(
    modelPath = "/path/to/model.gguf",
    systemPrompt = "You are a precise engineering assistant.",
    contextSize = 4096u
)
```

Note that `contextSize` is a `UInt`, hence the `u` suffix. Do not set it above what the model was trained for — read the ceiling from `model.maxCtx`:

```kotlin
val model = Model.load("/path/to/model.gguf")
val chat = Chat(model = model, contextSize = minOf(8192u, model.maxCtx))
```

Change the system prompt later:

```kotlin
chat.setSystemPrompt("You are a code reviewer.")
```

Reset the current context while optionally changing defaults:

```kotlin
chat.resetContext(systemPrompt = "You are a code reviewer.")
```

Or just clear the accumulated history:

```kotlin
chat.resetHistory()
```

Inspect context usage:

```kotlin
val stats = chat.getStats()
println("${stats.contextUsed} / ${stats.contextSize}")
```

Tokenize a message as the chat template would render it:

```kotlin
val tokens = chat.tokenize("Hello")
println(tokens)
```

## Template variables

Some models expose extra chat-template switches such as reasoning toggles.

```kotlin
val chat = Chat.fromPath(
    modelPath = "/path/to/model.gguf",
    templateVariables = mapOf("enable_thinking" to true)
)
```

Update them later:

```kotlin
chat.setTemplateVariable("enable_thinking", false)
println(chat.getTemplateVariables())
```

## GPU

GPU acceleration is enabled by default. Disable it with `useGpu = false` when needed:

```kotlin
val model = Model.load(
    modelPath = "/path/to/model.gguf",
    useGpu = false
)
```

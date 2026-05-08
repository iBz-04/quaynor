---
title: Sampling
description: Configure sampler presets and custom sampling pipelines in Swift.
sidebar_title: Sampling
order: 4
---

Sampling controls how the model chooses the next token from its probability distribution.

## Sampler presets

For common configurations, use `SamplerPresets`:

```swift
import Quaynor

let chat = try await Chat.fromPath(
    modelPath: "/path/to/model.gguf",
    sampler: SamplerPresets.temperature(0.2)
)
```

Available presets include:

- `SamplerPresets.default()`
- `SamplerPresets.dry()`
- `SamplerPresets.grammar(_:)`
- `SamplerPresets.greedy()`
- `SamplerPresets.json()`
- `SamplerPresets.temperature(_:)`
- `SamplerPresets.topK(_:)`
- `SamplerPresets.topP(_:)`

## Structured output

Use `json()` when you want strictly valid JSON output:

```swift
let chat = try await Chat.fromPath(
    modelPath: "/path/to/model.gguf",
    sampler: SamplerPresets.json()
)
```

For tighter formats, use a custom GBNF grammar:

```swift
let grammar = """
file ::= record (newline record)* newline?
record ::= field ("," field)*
field ::= quoted_field | unquoted_field
unquoted_field ::= [^,"\\n\\r]*
quoted_field ::= "\\"" ([^"] | "\\"\\"")* "\\""
newline ::= "\\r\\n" | "\\n"
"""

let chat = try await Chat.fromPath(
    modelPath: "/path/to/model.gguf",
    sampler: SamplerPresets.grammar(grammar)
)
```

## Custom sampler pipelines

Use `SamplerBuilder` when you need more control:

```swift
let sampler = SamplerBuilder()
    .temperature(temperature: 0.8)
    .topK(topK: 20)
    .dist()

let chat = try await Chat.fromPath(
    modelPath: "/path/to/model.gguf",
    sampler: sampler
)
```

You can also update the sampler on an existing chat:

```swift
try await chat.setSamplerConfig(sampler)
```

And inspect the current config:

```swift
let current = try await chat.getSamplerConfig()
let json = try current.toJson()
print(json)
```

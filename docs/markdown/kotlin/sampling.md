---
title: Sampling
description: Configure sampler presets and custom sampling pipelines in Kotlin.
sidebar_title: Sampling
order: 4
---

Sampling controls how the model chooses the next token from its probability distribution.

## Sampler presets

For common configurations, use `SamplerPresets`:

```kotlin
import ai.quaynor.Chat
import ai.quaynor.SamplerPresets

val chat = Chat.fromPath(
    modelPath = "/path/to/model.gguf",
    sampler = SamplerPresets.temperature(0.2f)
)
```

Available presets:

- `SamplerPresets.default()`
- `SamplerPresets.dry()`
- `SamplerPresets.grammar(grammar)`
- `SamplerPresets.greedy()`
- `SamplerPresets.json()`
- `SamplerPresets.temperature(temperature)`
- `SamplerPresets.topK(topK)`
- `SamplerPresets.topP(topP)`

The numeric presets take `Float`, so write `0.2f` rather than `0.2`.

## Structured output

Use `json()` when you want strictly valid JSON output:

```kotlin
val chat = Chat.fromPath(
    modelPath = "/path/to/model.gguf",
    sampler = SamplerPresets.json()
)
```

For tighter formats, use a custom GBNF grammar:

```kotlin
val grammar = """
file ::= record (newline record)* newline?
record ::= field ("," field)*
field ::= quoted_field | unquoted_field
unquoted_field ::= [^,"\n\r]*
quoted_field ::= "\"" ([^"] | "\"\"")* "\""
newline ::= "\r\n" | "\n"
""".trimIndent()

val chat = Chat.fromPath(
    modelPath = "/path/to/model.gguf",
    sampler = SamplerPresets.grammar(grammar)
)
```

Grammar constraints are enforced during sampling rather than checked afterwards, so the model cannot emit output that violates them.

## Custom sampler pipelines

Kotlin exposes a DSL through `buildSampler`. Chain any number of shift steps, then finish with a terminal step:

```kotlin
import ai.quaynor.buildSampler

val sampler = buildSampler {
    topK(40)
    temperature(0.8)
    minP(0.05)
    dist()
}

val chat = Chat.fromPath(
    modelPath = "/path/to/model.gguf",
    sampler = sampler
)
```

Shift steps: `topK`, `topP`, `minP`, `temperature`, `typicalP`, `xtc`, `grammar`, `dry`, `penalties`.

Terminal steps: `dist`, `greedy`, `mirostatV1`, `mirostatV2`. If you omit the terminal step, `dist()` is used. Calling two terminal steps throws `IllegalStateException`.

Order matters — steps are applied in the order you declare them, so `temperature` before `topK` behaves differently from the reverse.

Unlike the presets, the DSL takes `Double` for its floating-point arguments, so plain `0.8` is correct here:

```kotlin
val creative = buildSampler {
    temperature(1.1)
    topP(0.95)
    penalties(penaltyRepeat = 1.1)
    dist()
}

val deterministic = buildSampler { greedy() }
```

## Changing the sampler later

You can update the sampler on an existing chat:

```kotlin
chat.setSamplerConfig(sampler)
```

And inspect the current config as JSON:

```kotlin
println(chat.getSamplerConfigJson())
```

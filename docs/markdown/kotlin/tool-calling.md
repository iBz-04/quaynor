---
title: Tool Calling
description: Define tools in Kotlin and let Quaynor call them from a chat session.
sidebar_title: Tool Calling
order: 2
---

Tool calling lets the model invoke Kotlin functions for actions such as lookup, computation, or retrieval.

!!! info ""
    Not every model supports tool calling well. For reliable results, start with recent tool-capable instruction models such as the Qwen family.

## Declaring a tool

In Kotlin you pass an ordinary function reference. Parameter names, types, and the JSON schema are derived automatically through reflection, so there is no schema to write by hand.

```kotlin
import ai.quaynor.Tool
import kotlin.math.PI

fun circleArea(radius: Double): String {
    return "%.2f".format(PI * radius * radius)
}

val circleAreaTool = Tool(
    name = "circle_area",
    description = "Calculates the area of a circle from its radius.",
    function = ::circleArea
)
```

The function must return `String`. Supported parameter types are `String`, `Int`, `Long`, `Double`, `Float`, `Boolean`, and collections such as `List<String>` or `Map<String, Int>`. An unsupported type throws `IllegalArgumentException` when the `Tool` is constructed, not at call time.

Attach it when creating a chat:

```kotlin
val chat = Chat.fromPath(
    modelPath = "/path/to/model.gguf",
    tools = listOf(circleAreaTool)
)
```

Inspect the generated schema if you want to see what the model is shown:

```kotlin
println(circleAreaTool.getSchemaJson())
```

!!! warning "Local functions are not supported"
    The function must be a top-level function, a class method, or a companion object method. Functions declared inside another function or a lambda will not work — the Kotlin compiler mangles their JVM signatures and reflection cannot recover the parameter names.

## Suspend tools

`suspend` functions work exactly the same way:

```kotlin
suspend fun readStatus(): String {
    delay(200)
    return "Deployment healthy"
}

val readStatusTool = Tool(
    name = "read_status",
    description = "Reads the current deployment status.",
    function = ::readStatus
)
```

Suspend tools are executed with `runBlocking` on Quaynor's inference worker thread. That thread is dedicated to inference, so this does **not** block the main thread or any coroutine dispatcher — a slow tool delays only the response it belongs to.

## Structured parameters

Collections map onto JSON schema types, so a tool can take structured input without extra ceremony:

```kotlin
fun scheduleMeeting(title: String, durationMinutes: Int, attendees: List<String>): String {
    return "Scheduled '$title' for $durationMinutes minutes with ${attendees.size} attendees"
}

val scheduleMeetingTool = Tool(
    name = "schedule_meeting",
    description = "Schedules a meeting.",
    function = ::scheduleMeeting
)
```

Give parameters descriptive names — they appear verbatim in the schema the model sees, so `durationMinutes` guides it better than `d`.

## Updating tools on an existing chat

```kotlin
chat.setTools(listOf(circleAreaTool, readStatusTool))
```

Tool results are appended to the history as `Message.Tool` entries, which you can read back after a turn:

```kotlin
val toolResults = chat.getChatHistory().filterIsInstance<Message.Tool>()
for (result in toolResults) {
    println("${result.name} -> ${result.content}")
}
```

Tool calls consume context, so plan for a larger `contextSize` when your agent relies heavily on tools.

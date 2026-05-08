---
title: Tool Calling
description: Define tools in Swift and let Quaynor call them from a chat session.
sidebar_title: Tool Calling
order: 2
---

Tool calling lets the model invoke Swift callbacks for actions such as lookup, computation, or retrieval.

!!! info ""
    Not every model supports tool calling well. For reliable results, start with recent tool-capable instruction models such as the Qwen family.

## Declaring a tool

Each tool needs:

- a `name`
- a `description`
- ordered parameter definitions
- a callback that returns `String`

```swift
import Foundation
import Quaynor

let circleArea = Tool(
    name: "circle_area",
    description: "Calculates the area of a circle from its radius.",
    parameters: [
        ToolParameterDefinition(
            name: "radius",
            schema: .number(description: "The circle radius.")
        )
    ]
) { args in
    let radius = (args[0] as? Double) ?? 0
    let area = Double.pi * radius * radius
    return String(format: "%.2f", area)
}
```

Attach it when creating a chat:

```swift
let chat = try await Chat.fromPath(
    modelPath: "/path/to/model.gguf",
    tools: [circleArea]
)
```

## Async tools

Async callbacks work too:

```swift
let readStatus = Tool(
    name: "read_status",
    description: "Reads the current deployment status.",
    parameters: []
) { _ in
    try await Task.sleep(nanoseconds: 200_000_000)
    return "Deployment healthy"
}
```

## Object parameters

Use `ToolSchema.object` and related schema types when a tool needs structured arguments:

```swift
let scheduleMeeting = Tool(
    name: "schedule_meeting",
    description: "Schedules a meeting.",
    parameters: [
        ToolParameterDefinition(
            name: "request",
            schema: .object(
                properties: [
                    ToolProperty(
                        name: "title",
                        schema: .string(description: "Meeting title.")
                    ),
                    ToolProperty(
                        name: "duration_minutes",
                        schema: .integer(description: "Duration in minutes.")
                    )
                ],
                description: "The meeting request payload."
            )
        )
    ]
) { args in
    let request = args[0] as? [String: Any?] ?? [:]
    let title = request["title"] as? String ?? "Untitled"
    return "Scheduled \(title)"
}
```

## Updating tools on an existing chat

```swift
try await chat.setTools([circleArea, readStatus])
```

Tool calls consume context, so plan for a larger `contextSize` when your agent relies heavily on tools.

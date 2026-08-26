---
description: How to install the Quaynor Rust crate and run local LLM inference from Rust
---

# Getting started with Rust

Quaynor's engine is written in Rust, and the [`quaynor` crate](https://crates.io/crates/quaynor) gives you that engine directly — no FFI layer, no bridge, just the same API that powers every other binding.

## Install

```sh
cargo add quaynor
```

Building compiles `llama.cpp` from source, so you need **CMake** and a C/C++ toolchain installed. GPU acceleration is selected per platform automatically: **Metal** on macOS, **Vulkan** on x86/x86_64/aarch64 Linux and Windows.

## Chat

Models load from a local path, a URL, or a Hugging Face path (`hf://owner/repo/file.gguf`), downloaded and cached automatically:

```rust
use quaynor::chat::ChatBuilder;
use quaynor::llm::get_model;
use std::sync::Arc;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let model = Arc::new(get_model(
        "hf://bartowski/Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf",
        true, // use GPU if available
        None, // no multimodal projector
    )?);

    let chat = ChatBuilder::new(model)
        .with_context_size(4096)
        .with_system_prompt(Some("You are a helpful assistant."))
        .build();

    let mut stream = chat.ask("Is a zebra black or white?");
    while let Some(token) = stream.next_token() {
        print!("{token}");
    }
    Ok(())
}
```

Wait for the whole reply instead of streaming with `.completed()`:

```rust
let full = chat.ask("Why is the sky blue?").completed()?;
```

## Async

`ChatBuilder::build_async()` returns a `ChatHandleAsync` for use inside a Tokio runtime:

```rust
let chat = ChatBuilder::new(model).build_async();
let mut stream = chat.ask("Tell me a joke");
while let Some(token) = stream.next_token().await {
    print!("{token}");
}
```

## Tool calling

Tools are grammar-constrained with GBNF, so the model can only produce valid calls:

```rust
use quaynor::tool_calling::Tool;
use std::sync::Arc;

let circle_area = Tool::new(
    "circle_area",
    "Area of a circle from radius",
    serde_json::json!({
        "type": "object",
        "properties": { "radius": { "type": "number" } },
        "required": ["radius"]
    }),
    Arc::new(|args| {
        let r = args["radius"].as_f64().unwrap_or(0.0);
        format!("{:.2}", std::f64::consts::PI * r * r)
    }),
);

let chat = ChatBuilder::new(model).with_tool(circle_area).build();
```

Two sandboxed tools ship built in: `Tool::python(..)` runs snippets in the [monty](https://crates.io/crates/monty) interpreter and `Tool::bash(..)` in the [bashkit](https://crates.io/crates/bashkit) virtual shell — both isolated from the host filesystem and network.

## Beyond chat

| Module | What it does |
|--------|--------------|
| `quaynor::encoder` | Embedding generation |
| `quaynor::crossencoder` | Cross-encoder reranking |
| `quaynor::tokenizer` | Tokenize / detokenize helpers |
| `quaynor::template` | Minijinja chat-template rendering |
| `quaynor::sampler_config` | Sampler presets and full sampler chains |

## Logging

Quaynor uses the [`tracing`](https://crates.io/crates/tracing) ecosystem. Forward llama.cpp's own logs into it with:

```rust
quaynor::send_llamacpp_logs_to_tracing();
```

Full API reference lives on [docs.rs/quaynor](https://docs.rs/quaynor).

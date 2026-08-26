<div align="center">
   <h1>QUAYNOR</h1>
</div>

<p align="center"><b>A lightweight, blazing fast AI inference engine written in Rust.</b></p>

Embed **local LLMs** in your app: load GGUF checkpoints, chat on-device or on the GPU, and keep data off the cloud. This crate is the Rust engine that also powers the [Python](https://pypi.org/project/quaynor/), [Flutter](https://pub.dev/packages/quaynor), [React Native](https://www.npmjs.com/package/react-native-quaynor), Swift, and Kotlin bindings.

**Documentation:** [www.quaynor.site](https://www.quaynor.site) · [docs.rs/quaynor](https://docs.rs/quaynor)

## Install

```sh
cargo add quaynor
```

GPU backends are enabled per platform: **Metal** on macOS/iOS, **Vulkan** on desktop x86/x86_64/aarch64 Linux and Windows. Building compiles `llama.cpp` from source via [`llama-cpp-2`](https://crates.io/crates/llama-cpp-2), so you need CMake and a C/C++ toolchain.

## Chat

Models load from local paths, plain URLs, or Hugging Face paths (`hf://owner/repo/file.gguf`, downloaded and cached automatically):

```rust,no_run
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

    // Stream tokens as they arrive...
    let mut stream = chat.ask("Is a zebra black or white?");
    while let Some(token) = stream.next_token() {
        print!("{token}");
    }

    // ...or wait for the full response (idempotent after streaming).
    let full = chat.ask("Why is the sky blue?").completed()?;
    println!("{full}");
    Ok(())
}
```

Prefer async? `ChatBuilder::build_async()` returns a `ChatHandleAsync` whose `ask` yields a `TokenStreamAsync` with `next_token().await` / `completed().await`.

## Tool calling

Grammar-constrained tool use via GBNF — the model can only emit valid calls:

```rust,no_run
use quaynor::chat::ChatBuilder;
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

# let model: Arc<quaynor::llm::Model> = unimplemented!();
let chat = ChatBuilder::new(model).with_tool(circle_area).build();
```

Built-in sandboxed tools are available too: `Tool::python(..)` (via [monty](https://crates.io/crates/monty)) and `Tool::bash(..)` (via [bashkit](https://crates.io/crates/bashkit)) — both fully isolated from the host.

## Beyond chat

- **Embeddings** — `quaynor::encoder` for embedding generation.
- **Reranking** — `quaynor::crossencoder` for cross-encoder scoring.
- **Tokenizer utilities** — `quaynor::tokenizer`.
- **Chat templates** — Minijinja-rendered model chat templates in `quaynor::template`.
- **Sampling** — presets and full sampler chains in `quaynor::sampler_config`.
- **Vision** — pass a multimodal projector to `get_model` and send image prompts where the model supports it.

## Logging

Forward llama.cpp logs into the `tracing` ecosystem:

```rust
quaynor::send_llamacpp_logs_to_tracing();
```

## License

MIT

# AGENTS.md

Essential information for AI agents working on the Quaynor codebase.

## Agent workflow

After any change to the repo (including small doc or config edits), **commit and push to `origin`** in the same session unless the user asks not to.

## Project Overview

Quaynor is a  lightweight local AI inference library for running LLMs offline. Core features include streaming responses, tool calling, and context management. 

## Architecture
### Core Rust Library

The main implementation is in `quaynor/core/src/`:

- [`chat.rs`](quaynor/core/src/chat.rs) - Chat API with conversation management
- [`llm.rs`](quaynor/core/src/llm.rs) - Model loading and worker management
- [`encoder.rs`](quaynor/core/src/encoder.rs) - Embeddings generation
- [`crossencoder.rs`](quaynor/core/src/crossencoder.rs) - Cross-encoder for reranking
- [`memory.rs`](quaynor/core/src/memory.rs) - Memory estimation
- [`template.rs`](quaynor/core/src/template.rs) - Chat template rendering
- [`tokenizer.rs`](quaynor/core/src/tokenizer.rs) - Tokenizer utilities
- [`tool_calling/`](quaynor/core/src/tool_calling) - Grammar-based tool calling
- [`errors.rs`](quaynor/core/src/errors.rs) - Error types using `thiserror`
- [`sampler_config.rs`](quaynor/core/src/sampler_config.rs) - Sampling configuration

### Language Bindings

- **Python** ([`quaynor/python/`](quaynor/python/)) - PyO3/maturin bindings
- **Flutter** ([`quaynor/flutter/`](quaynor/flutter/)) - FFI bindings via `flutter_rust_bridge`
- **React Native** — UniFFI bindings (see [`quaynor/uniffi/`](quaynor/uniffi/) and package `react-native-quaynor`)

## Key Types & Patterns

### Core Types

- `ChatHandle` / `ChatHandleAsync` - Main chat interface (sync and async)
- `ChatBuilder` - Builder pattern for chat configuration
- `Message` enum - User/Assistant/System/Tool messages
- `Model` - Shared model instance (`Arc<LlamaModel>`)
- `Worker` - Background task for model inference

### Error Handling

Uses `thiserror` crate for error types. All errors are defined in [`errors.rs`](quaynor/core/src/errors.rs) and implement `std::error::Error`. Common error types include `LoadModelError`, `InitWorkerError`, `ChatWorkerError`.

### Key Dependencies

- `llama-cpp-2` - underlying LLM inference engine
- `tokio` - Async runtime
- `serde` / `serde_json` - Serialization
- `minijinja` - Template rendering for chat templates
- `gbnf` - Grammar-based tool calling
- `tracing` - Logging framework

## Build & Test

### Building

**Core library:**
```bash
cd quaynor
cargo build
```

**Python bindings:**
```bash
cd quaynor/python
maturin develop --uv
cargo run --bin make_stubs  # Generate type stubs
```

### Testing

**Core tests:**
```bash
cd quaynor
export TEST_MODEL=/path/to/model.gguf
cargo test -- --nocapture --test-threads=1
```

**Python tests:**
```bash
cd quaynor/python
pytest  # Also tests markdown documentation code blocks
```

### Development Environment

- **Linux/WSL:** Use Nix flakes (`nix develop`)
- **Windows:** Install rustup, cmake, llvm, msvc, and Vulkan SDK

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for detailed setup instructions.

## Development Notes

### Platform Support

- Desktop (all bindings): Windows, Linux, macOS
- Android: Flutter and React Native bindings
- iOS: Flutter and React Native bindings
- GPU acceleration: Vulkan (x86/x86_64), Metal (macOS/iOS)

### Integration Patterns

**Python:**
- Use `#[pyclass]` for classes and `#[pymethods]` for methods
- See [`quaynor/python/src/lib.rs`](quaynor/python/src/lib.rs) for examples

**Flutter:**
- Uses `flutter_rust_bridge` for FFI bindings
- See [`quaynor/flutter/rust/src/lib.rs`](quaynor/flutter/rust/src/lib.rs) for examples

### Code Patterns

- Use `Arc<LlamaModel>` for shared model instances
- Builder pattern for configuration (`ChatBuilder`)
- Async support via `tokio` (`ChatHandleAsync`)
- Error propagation with `?` operator
- Tracing for logging (`tracing::info!`, `tracing::debug!`, etc.)

## Important Files

- [`quaynor/core/src/chat.rs`](quaynor/core/src/chat.rs) - Main chat API
- [`quaynor/core/src/llm.rs`](quaynor/core/src/llm.rs) - Model and worker management
- [`quaynor/core/Cargo.toml`](quaynor/core/Cargo.toml) - Core dependencies
- [`quaynor/python/src/lib.rs`](quaynor/python/src/lib.rs) - Python bindings
- [`CONTRIBUTING.md`](CONTRIBUTING.md) - Development setup
- [`README.md`](README.md) - User-facing documentation

## Documentation
Documentation is available under the `docs/` folder, but also at: docs.quaynor.ooo.


# Developer guide

Architecture, conventions, and workflows for **contributors** mapping the codebase and for **AI coding assistants** using this repo as context.

## Automation workflow (AI assistants)

After any change to the repo (including small doc or config edits), **commit and push ** in the same session unless the user asks not to. Commit messages must describe the change only. If the shell’s `git` command auto-appends such a footer, use your system `git` binary (e.g. `/usr/bin/git` on macOS) so the commit message stays clean.

## GitHub

- **Repository:** https://github.com/iBz-04/quaynor
- **Issues:** https://github.com/iBz-04/quaynor/issues — bugs and regressions
- **Discussions:** https://github.com/iBz-04/quaynor/discussions — questions and feature discussion
- **CI:** [`main.yml`](.github/workflows/main.yml) composes reusable workflows such as [`build.yml`](.github/workflows/build.yml), [`python_ci.yml`](.github/workflows/python_ci.yml), and [`react_native_ci.yml`](.github/workflows/react_native_ci.yml). Pull requests can trigger a broader matrix when labeled **`full-ci`** (see `full_ci` inputs in `main.yml`).

Prefer pull requests for non-trivial changes; follow [`CONTRIBUTING.md`](CONTRIBUTING.md) for local setup and conventions.

## Project Overview

Quaynor is a lightweight local AI inference library for running LLMs offline. Core features include streaming responses, tool calling, and context management.

## Repository layout

- **Repository root** — Top-level [`README.md`](README.md), this guide, [`LICENSE`](LICENSE), CI under [`.github/workflows/`](.github/workflows/), and user docs source under [`docs/markdown/`](docs/markdown/) (the published site build output is typically ignored; see [`.gitignore`](.gitignore)).
- **`quaynor/`** — The **Cargo workspace** root ([`quaynor/Cargo.toml`](quaynor/Cargo.toml)): shared Rust core, CLI, grammar helpers, and most bindings. Run `cargo` commands from here unless a binding README says otherwise.

### Cargo workspace members

| Crate / path | Role |
|--------------|------|
| [`quaynor/core/`](quaynor/core/) | Engine: chat, model load, templates, tool calling, embeddings, errors |
| [`quaynor/cli/`](quaynor/cli/) | Command-line tooling |
| [`quaynor/python/`](quaynor/python/) | PyO3 / maturin Python extension |
| [`quaynor/flutter/rust/`](quaynor/flutter/rust/) | Rust side of Flutter (`flutter_rust_bridge`) |
| [`quaynor/uniffi/`](quaynor/uniffi/) | UniFFI scaffolding for React Native and other consumers |
| [`quaynor/grammar/gbnf/`](quaynor/grammar/gbnf/), [`quaynor/grammar/gbnf-macro/`](quaynor/grammar/gbnf-macro/) | GBNF grammar support used with tool calling |

The workspace [`Cargo.toml`](quaynor/Cargo.toml) may pin or patch dependencies (for example PyO3); check there before assuming crates.io versions.

### Swift package (outside Cargo)

[`quaynor/swift/`](quaynor/swift/) is a **SwiftPM** package (`Package.swift`) with its own build story and FFI bindings. It is **not** listed in the Cargo workspace; see [`quaynor/swift/README.md`](quaynor/swift/README.md) and [`quaynor/swift/RELEASING.md`](quaynor/swift/RELEASING.md) for Swift-specific work.

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
- **React Native** — UniFFI bindings (see [`quaynor/uniffi/`](quaynor/uniffi/), [`quaynor/react-native/`](quaynor/react-native/), npm package `react-native-quaynor`)
- **Swift** — [`quaynor/swift/`](quaynor/swift/) SwiftPM package wrapping the native FFI

### Tool-calling stack

Grammar-constrained tool use builds on **GBNF** (see [`quaynor/core/src/tool_calling/`](quaynor/core/src/tool_calling/) and the `grammar/` crates above). When changing grammars or parsers, keep Python, Flutter, and RN surfaces consistent with the core behavior.

## Key Types & Patterns

### Core Types

- `ChatHandle` / `ChatHandleAsync` - Main chat interface (sync and async)
- `ChatBuilder` - Builder pattern for chat configuration
- `Message` enum - User/Assistant/System/Tool messages
- `Model` - Shared model instance (`Arc<LlamaModel>`)
- `Worker` - Background task for model inference

### Error Handling

Uses `thiserror` crate for error types. All errors are defined in [`errors.rs`](quaynor/core/src/errors.rs) and implement `std::error::Error`. Common error types include `LoadModelError`, `InitWorkerError`, `ChatWorkerError`.

Prefer extending existing error enums or variants there rather than ad-hoc strings in bindings, so Python / FFI layers can map failures consistently.

### Logging and diagnostics

The core crate exposes [`send_llamacpp_logs_to_tracing`](quaynor/core/src/lib.rs) to forward **llama.cpp** logs into the **`tracing`** ecosystem. Use `tracing` spans and levels (`debug!`, `info!`, …) for new instrumentation so downstream apps can filter verbosity consistently.

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

Many integration-style tests load real GGUF files. Use **`--test-threads=1`** when tests touch the GPU or global llama state to reduce flakes.

Optional environment variables used by test helpers in [`quaynor/core/src/lib.rs`](quaynor/core/src/lib.rs) (`test_utils`):

| Variable | Purpose |
|----------|---------|
| `TEST_MODEL` | Primary chat model path (default placeholder: `model.gguf`) |
| `TEST_EMBEDDINGS_MODEL` | Embeddings GGUF |
| `TEST_CROSSENCODER_MODEL` | Cross-encoder GGUF |
| `TEST_MMPROJ` | Multimodal projector path |
| `TEST_VISION_MODEL` | Vision model GGUF |

If a test fails to load weights, confirm the path and that the artifact matches the scenario (chat vs embeddings vs vision).

**Python tests:**
```bash
cd quaynor/python
pytest  # Also tests markdown documentation code blocks
```

### Development Environment

- **Linux/WSL:** Use Nix flakes (`nix develop`)
- **Windows:** Install rustup, cmake, llvm, msvc, and Vulkan SDK

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for detailed setup instructions.

### Flutter and React Native

- **Flutter:** Rust crate under [`quaynor/flutter/rust/`](quaynor/flutter/rust/); Dart package under [`quaynor/flutter/quaynor/`](quaynor/flutter/quaynor/). Run `flutter`/Dart tooling from the Flutter package directory when iterating on the app-facing API.
- **React Native:** TurboModule and codegen docs under [`quaynor/react-native/`](quaynor/react-native/) (see `DEVELOPMENT.md` there for UniFFI / JSI details).

## Development Notes

### Human contributors

Use Issues for defects and Discussions for design questions. For pull requests: keep changes scoped, describe behavior and risk in the PR body, and run the most relevant checks locally (`cargo test`, `pytest`, or binding-specific scripts) before requesting review. Maintainers may apply the **`full-ci`** PR label when a change needs the wider matrix described in [`.github/workflows/main.yml`](.github/workflows/main.yml).

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

### Code quality

- Avoid **monolithic files**: split logic into appropriate modules or types instead of dumping unrelated code into one large file.
- Prioritize **clean, clear code** — straightforward structure, naming, and control flow over clever or compressed shortcuts.

### Code Patterns

- Use `Arc<LlamaModel>` for shared model instances
- Builder pattern for configuration (`ChatBuilder`)
- Async support via `tokio` (`ChatHandleAsync`)
- Error propagation with `?` operator
- Tracing for logging (`tracing::info!`, `tracing::debug!`, etc.)

## Important Files

- [`DEVELOPER-GUIDE.md`](DEVELOPER-GUIDE.md) — This orientation guide (architecture and dev conventions)
- [`quaynor/Cargo.toml`](quaynor/Cargo.toml) — Workspace members and dependency patches
- [`quaynor/core/src/chat.rs`](quaynor/core/src/chat.rs) - Main chat API
- [`quaynor/core/src/llm.rs`](quaynor/core/src/llm.rs) - Model and worker management
- [`quaynor/core/Cargo.toml`](quaynor/core/Cargo.toml) - Core dependencies
- [`quaynor/python/src/lib.rs`](quaynor/python/src/lib.rs) - Python bindings
- [`README.md`](README.md) - User-facing documentation

## Documentation

Authoritative user docs live at [www.quaynor.site](https://www.quaynor.site). In-repo sources are under [`docs/markdown/`](docs/markdown/) (binding guides, chat, tool calling, sampling, vision, etc.). After structural doc edits, run binding tests or site generation if your change touches embedded examples.

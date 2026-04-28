# Quaynor

**Run LLMs locally and efficiently on any device**

Quaynor is a lightweight, open-source inference engine that makes it simple to run open-weights language models directly inside your Python applications. No API keys, no cloud infrastructure, no complexity—just fast, easy local AI.

## Key Features

- **Run locally, offline, for free** - No API keys or cloud services required
- **Fast, simple tool calling** - Just pass normal Python functions
- **Reliable tool execution** - Automatically derives grammar from function signatures
- **Infinite conversations** - Conversation-aware preemptive context shifting prevents mid-conversation crashes
- **GPU accelerated** - Vulkan-powered inference for maximum performance
- **Thousands of compatible models** - Works with any LLM in GGUF format
- **Powered by llama.cpp** - Built on the proven [llama.cpp](https://github.com/ggml-org/llama.cpp) engine

## Quick Start

```python
from quaynor import Chat

chat = Chat('./model.gguf')
response = chat.ask('Hello world?').completed()
print(response)
```

## Installation

```bash
pip install quaynor
```

## Documentation

Full documentation: https://docs.quaynor.ooo/

## License

MIT — see the repository `LICENSE` file.

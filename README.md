<div align="center">

<h2>Quaynor</h2>

<p><b>A lightweight, blazing fast AI inference engine written in Rust.</b></p>

</div>

Embed **local LLMs** in your app: load GGUF checkpoints, chat on-device or on the GPU, and keep data off the cloud. Powered by **[llama.cpp](https://github.com/ggml-org/llama.cpp)** — bindings for **Python**, **Flutter**, and **React Native**.

**Docs:** [www.quaynor.site](https://www.quaynor.site)

---

## Why use it

- **Offline inference** — No inference API keys; models stay on disk or load from URLs / Hugging Face paths you choose.
- **One chat-style API across bindings** — `Chat`/`ask` patterns align so you can move ideas between Python, Flutter, and React Native without relearning primitives.
- **Production-oriented features** — Streaming replies, bounded context sizing, embeddings and cross-encoder reranking where supported, grammar-based tool calling wired from native functions (Python) or equivalents in mobile bindings.

**Rough capability map:**

| Area | Notes |
|------|--------|
| Chat & streaming | Token streaming and full-string completion helpers (e.g. `.completed()`). |
| Tool calling | Grammar-constrained tool use; decorate Python functions or declare tools in RN/Flutter per docs. |
| Hardware | Vulkan (desktop/Android where applicable), Metal (Apple). |
| Modalities | Vision and audio pipelines where the model supports them; see docs for model quirks. |

---

## Flutter

[`quaynor` on pub.dev](https://pub.dev/packages/quaynor)

```sh
flutter pub add quaynor
```

```dart
import 'package:quaynor/quaynor.dart' as quaynor;

void main() async {
  await quaynor.Quaynor.init();
  final chat = await quaynor.Chat.fromPath(
    modelPath: 'huggingface:bartowski/Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf',
  );
  final msg = await chat.ask('Is a zebra black or white?').completed();
  print(msg);
}
```

---

## React Native

[`react-native-quaynor` on npm](https://www.npmjs.com/package/react-native-quaynor)

```sh
npm install react-native-quaynor
```

```typescript
import { Chat } from "react-native-quaynor";

const chat = await Chat.fromPath({
  modelPath: "hf://bartowski/Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf",
});

const msg = await chat.ask("Is a zebra black or white?").completed();
console.log(msg);
```

---

## Python

[`quaynor` on PyPI](https://pypi.org/project/quaynor/)

```sh
pip install quaynor
```

```python
from quaynor import Chat

chat = Chat("huggingface:bartowski/Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf")
for token in chat.ask("Is a zebra black or white?"):
    print(token, end="", flush=True)
```

Wait for the full string with `.completed()`:

```python
full = chat.ask("Why is the sky blue?").completed()
```

**Tool calling:**

```python
import math
from quaynor import tool, Chat

@tool(description="Area of a circle from radius")
def circle_area(radius: float) -> str:
    return f"{math.pi * radius ** 2:.2f}"

chat = Chat("./path/to/model.gguf", tools=[circle_area])
```

---

## Platforms

Desktop (Windows, Linux, macOS): all bindings. **Android** and **iOS**: Flutter and React Native bindings (Metal on Apple, Vulkan where enabled on Android).

---

## Contributing

Issues, discussions, and PRs are welcome. See the repo labels and **[www.quaynor.site](https://www.quaynor.site)** for setup and binding-specific guides.

---

## License

[MIT](LICENSE)

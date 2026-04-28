# Quaynor

Run LLMs locally with offline inference. Bindings for **Python**, **Flutter**, and **React Native**. Uses [llama.cpp](https://github.com/ggml-org/llama.cpp) and GGUF models.

**Features:** streaming chat, tool calling (grammar derived from your functions), GPU inference (Vulkan / Metal), vision and audio inputs, optional model download from Hugging Face or URLs.

**Docs:** [www.quaynor.site](https://www.quaynor.site)

---

## Flutter

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
full = chat.ask("Is water wet?").completed()
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

Desktop (Windows, Linux, macOS) is supported for all listed bindings. Android and iOS are supported for Flutter and React Native.

---

## Contributing

Star the repo, report issues, or open PRs.
---

## License

[MIT](LICENSE)

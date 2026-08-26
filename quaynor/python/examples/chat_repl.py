#!/usr/bin/env python3
"""Interactive chat with a local GGUF through Quaynor.

  uv run python examples/chat_repl.py /path/to/model.gguf
  uv run python examples/chat_repl.py   # uses TEST_MODEL or macOS Quaynor cache path below

Empty line or Ctrl-D to quit.
"""
from __future__ import annotations

import os
import sys

import quaynor

# Default: typical Quaynor HF cache layout on macOS/Linux (dirs::cache_dir()/quaynor/models/...).
_DEFAULT_CANDIDATES = (
    os.environ.get("TEST_MODEL"),
    os.path.expanduser(
        "~/Library/Caches/quaynor/models/bartowski/"
        "Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf"
    ),
    os.path.expanduser(
        "~/.cache/quaynor/models/bartowski/"
        "Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf"
    ),
)


def _resolve_model_path(argv: list[str]) -> str:
    if len(argv) > 1:
        return argv[1]
    for p in _DEFAULT_CANDIDATES:
        if p and os.path.isfile(p):
            return p
    print(
        "Usage: python chat_repl.py /path/to/model.gguf\n"
        "Or set TEST_MODEL to a .gguf file.",
        file=sys.stderr,
    )
    sys.exit(1)


def main() -> None:
    if sys.platform == "win32":
        sys.stdout.reconfigure(encoding="utf-8")

    path = _resolve_model_path(sys.argv)
    print(f"Loading {path} …")
    model = quaynor.Model(path)
    chat = quaynor.Chat(
        model,
        system_prompt="You are a helpful assistant.",
        template_variables={"enable_thinking": False},
    )
    print("Ready. Type a message (empty line or Ctrl-D to quit).\n")

    while True:
        try:
            line = input("You: ").strip()
        except EOFError:
            print()
            break
        if not line:
            break
        print("Assistant: ", end="", flush=True)
        for token in chat.ask(line):
            print(token, end="", flush=True)
        print("\n")


if __name__ == "__main__":
    main()

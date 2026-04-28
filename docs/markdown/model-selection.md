---
title: Model Selection
description: How to pick GGUF models for Quaynor — Hugging Face paths, naming, quantization, memory estimates, and external benchmarks.
sidebar_title: Model Selection
order: 7
---

Choosing a model affects speed, RAM use, and quality. Prefer the **smallest** model that still meets your task; larger models cost more memory and latency for often marginal gains.

## TL;DR

Solid default (~2 GB chat model):

```
huggingface:bartowski/Qwen_Qwen3-4B-GGUF/Qwen_Qwen3-4B-Q4_K_M.gguf
```

Smaller and faster:

```
huggingface:bartowski/Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf
```

Pass these wherever Quaynor expects a model path (`Chat`, `Model`, `Encoder`, etc.). First use triggers a download; later loads read from cache and work offline.

## Getting a model

Quaynor can fetch GGUF weights from Hugging Face. Pass a **`huggingface:`** URI instead of a local path:

```
huggingface:owner/repo/filename.gguf
```

Files are downloaded once and cached — after that, no network is needed for that model. **`hf:`** is accepted as shorthand.

You can pass any **`https://`** URL if the server serves a GGUF directly, or keep using ordinary filesystem paths if you manage files yourself.

Common starting points for GGUF mirrors: [**Bartowski**](https://huggingface.co/bartowski), [**Unsloth**](https://huggingface.co/unsloth/models), and [**Qwen**](https://huggingface.co/Qwen). Most public `.gguf` files on [Hugging Face](https://huggingface.co) work; odd exports sometimes fail — Quaynor surfaces a clear error when something is incompatible.

## Understanding file names

A typical chat filename looks like `Qwen_Qwen3-0.6B-Q4_K_M.gguf`:

| Segment | Meaning |
|---------|---------|
| `Qwen` | Publisher or family |
| `Qwen3` | Release line |
| `0.6B` | Size in billions of parameters |
| `Q4` | Quantization level (bits per weight, approximately) |
| `K_M` | Quant variant (e.g. `S` faster / rougher, `L` slower / sharper, `M` balanced) |

For **chat**, use instruction-tuned GGUF builds that include a chat template in metadata. That matches typical Hugging Face chat releases. Quaynor errors early if the template cannot be applied.

For **embeddings** or **reranking / cross-encoder** tasks, choose models labeled for those jobs; reranking models sometimes appear under “reranker” or “cross-encoder” names.

## Quantization

Quantization stores weights in fewer bits so models use less RAM and often run faster, with small quality trade-offs. **Q4** and **Q5** tiers are typical sweet spots for chat.

Rough rule: prefer **more parameters at lower bit width** over **fewer parameters at higher precision** unless you have benchmarks saying otherwise — but task-specific testing beats rules of thumb.

## Estimating memory

Approximate VRAM/RAM demand scales with parameter count × effective bytes per parameter from quantization. Illustrative anchors:

| Example | Rough RAM |
|---------|-----------|
| 2 B params @ Q8 | ~2 GB |
| 2 B @ Q4 | ~1 GB |
| 14 B @ Q4 | ~7 GB |
| 14 B @ Q2 | ~3.5 GB |

Treat these as order-of-magnitude guides; backends and KV cache add overhead.

## Comparing models online

Independent leaderboards help narrow candidates before you download:

- **[LLM-Stats.com](https://llm-stats.com/)** — filters for open / smaller models alongside common benchmarks.
- **[OpenEvals (Hugging Face)](https://huggingface.co/spaces/OpenEvals/find-a-leaderboard)** — many task-specific boards; mixes open weights with closed APIs.

You need weights published as GGUF files; models that exist only behind a vendor API cannot be run locally here.

---

If two models trade off oddly for your workload, **[GitHub Discussions](https://github.com/iBz-04/quaynor/discussions)** is the best place to compare notes with other Quaynor users; use **[Issues](https://github.com/iBz-04/quaynor/issues)** when something looks broken.

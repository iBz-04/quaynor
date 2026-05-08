---
title: Embeddings & RAG
description: Build embedding search and reranking workflows from Swift.
sidebar_title: Embeddings & RAG
order: 5
---

When you need semantic search, retrieval, or reranking, use `Encoder` and `CrossEncoder`.

## The Encoder

An `Encoder` converts text into embedding vectors.

```swift
import Quaynor

let encoder = try await Encoder.fromPath(
    modelPath: "/path/to/embedding-model.gguf"
)
let embedding = try await encoder.encode("How do I reset my password?")
print(embedding.count)
```

A good starting model is [bge-small-en-v1.5-q8_0.gguf](https://huggingface.co/CompendiumLabs/bge-small-en-v1.5-gguf/resolve/main/bge-small-en-v1.5-q8_0.gguf).

## Comparing embeddings

Use cosine similarity to compare semantic closeness:

```swift
let query = try await encoder.encode("How do I reset my password?")
let doc1 = try await encoder.encode("Reset your password from account settings.")
let doc2 = try await encoder.encode("Office hours are Monday through Friday.")

let score1 = cosineSimilarity(a: query, b: doc1)
let score2 = cosineSimilarity(a: query, b: doc2)

print(score1)
print(score2)
```

## CrossEncoder reranking

Embeddings are useful for broad retrieval. `CrossEncoder` is useful for higher-quality ranking.

```swift
let crossEncoder = try await CrossEncoder.fromPath(
    modelPath: "/path/to/reranker-model.gguf"
)

let documents = [
    "Someone asked how to install Python packages.",
    "Use pip install package-name to install Python packages.",
    "Python packages are not all in the standard library."
]

let scores = try await crossEncoder.rank(
    query: "How do I install Python packages?",
    documents: documents
)
print(scores)
```

To get the documents already sorted by relevance:

```swift
let ranked = try await crossEncoder.rankAndSort(
    query: "How do I install Python packages?",
    documents: documents
)

for row in ranked {
    print("\(row.score): \(row.document)")
}
```

## Using RAG with tools

One practical setup is:

1. retrieve or rerank documents
2. expose that retrieval as a tool
3. let the chat model call it when needed

```swift
let knowledge = [
    "Returns are accepted within 30 days.",
    "Free shipping starts at $50.",
    "Support is available Monday through Friday."
]

let searchKnowledge = Tool(
    name: "search_knowledge",
    description: "Searches internal policy documents.",
    parameters: [
        ToolParameterDefinition(
            name: "query",
            schema: .string(description: "The search query.")
        )
    ]
) { args in
    let query = (args[0] as? String) ?? ""
    let ranked = try await crossEncoder.rankAndSort(query: query, documents: knowledge)
    return ranked.prefix(3).map(\.document).joined(separator: "\n")
}

let chat = try await Chat.fromPath(
    modelPath: "/path/to/chat-model.gguf",
    systemPrompt: "Use search_knowledge before answering policy questions.",
    tools: [searchKnowledge]
)
```

## Recommended models

- Embeddings: `bge-small-en-v1.5-q8_0.gguf`
- Reranking: `bge-reranker-v2-m3-Q8_0.gguf`

For large collections, use embeddings to narrow the candidate set first, then rerank with a cross-encoder.

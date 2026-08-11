---
title: Embeddings & RAG
description: Build embedding search and reranking workflows from Kotlin.
sidebar_title: Embeddings & RAG
order: 5
---

When you need semantic search, retrieval, or reranking, use `Encoder` and `CrossEncoder`.

## The Encoder

An `Encoder` converts text into embedding vectors.

```kotlin
import ai.quaynor.Encoder

val encoder = Encoder.fromPath(modelPath = "/path/to/embedding-model.gguf")
val embedding = encoder.encode("How do I reset my password?")
println(embedding.size)
```

A good starting model is [bge-small-en-v1.5-q8_0.gguf](https://huggingface.co/CompendiumLabs/bge-small-en-v1.5-gguf/resolve/main/bge-small-en-v1.5-q8_0.gguf).

Embedding models are small enough that GPU acceleration rarely helps, and running them on CPU leaves the GPU free for your chat model:

```kotlin
val encoder = Encoder.fromPath(
    modelPath = "/path/to/embedding-model.gguf",
    useGpu = false,
    contextSize = 1024u
)
```

## Comparing embeddings

Use cosine similarity to compare semantic closeness:

```kotlin
import ai.quaynor.cosineSimilarity

val query = encoder.encode("How do I reset my password?")
val doc1 = encoder.encode("Reset your password from account settings.")
val doc2 = encoder.encode("Office hours are Monday through Friday.")

println(cosineSimilarity(query, doc1))
println(cosineSimilarity(query, doc2))
```

## CrossEncoder reranking

Embeddings are useful for broad retrieval. `CrossEncoder` is useful for higher-quality ranking.

```kotlin
import ai.quaynor.CrossEncoder

val crossEncoder = CrossEncoder.fromPath(modelPath = "/path/to/reranker-model.gguf")

val documents = listOf(
    "Someone asked how to install Python packages.",
    "Use pip install package-name to install Python packages.",
    "Python packages are not all in the standard library."
)

val scores = crossEncoder.rank(
    query = "How do I install Python packages?",
    documents = documents
)
println(scores)
```

`rank` returns scores in the same order as the input documents. To get them already sorted by relevance, use `rankAndSort`, which returns `(document, score)` pairs:

```kotlin
val ranked = crossEncoder.rankAndSort(
    query = "How do I install Python packages?",
    documents = documents
)

for ((document, score) in ranked) {
    println("$score: $document")
}
```

## Using RAG with tools

One practical setup is:

1. retrieve or rerank documents
2. expose that retrieval as a tool
3. let the chat model call it when needed

Because tools are plain function references, the retrieval function needs access to the cross-encoder. Putting both in a class keeps the reflection requirements satisfied — a method reference works, a closure does not:

```kotlin
import ai.quaynor.Chat
import ai.quaynor.CrossEncoder
import ai.quaynor.Tool

class KnowledgeBase(private val crossEncoder: CrossEncoder) {
    private val documents = listOf(
        "Returns are accepted within 30 days.",
        "Free shipping starts at $50.",
        "Support is available Monday through Friday."
    )

    suspend fun search(query: String): String {
        return crossEncoder.rankAndSort(query, documents)
            .take(3)
            .joinToString("\n") { (document, _) -> document }
    }
}

val knowledgeBase = KnowledgeBase(crossEncoder)

val searchTool = Tool(
    name = "search_knowledge",
    description = "Searches internal policy documents.",
    function = knowledgeBase::search
)

val chat = Chat.fromPath(
    modelPath = "/path/to/chat-model.gguf",
    systemPrompt = "Use search_knowledge before answering policy questions.",
    tools = listOf(searchTool)
)
```

## Recommended models

- Embeddings: `bge-small-en-v1.5-q8_0.gguf`
- Reranking: `bge-reranker-v2-m3-Q8_0.gguf`

For large collections, use embeddings to narrow the candidate set first, then rerank with a cross-encoder. Running a cross-encoder over every document is far more expensive than an embedding lookup, since it scores each query–document pair individually.

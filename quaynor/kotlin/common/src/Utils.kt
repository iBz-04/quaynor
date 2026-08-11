package ai.quaynor

import uniffi.quaynor.cosineSimilarity as internalCosineSimilarity
import uniffi.quaynor.deleteCachedModel as internalDeleteCachedModel
import uniffi.quaynor.getCachedModels as internalGetCachedModels

/** Compute the cosine similarity between two vectors. */
fun cosineSimilarity(a: List<Float>, b: List<Float>): Float {
    return internalCosineSimilarity(a, b)
}

/** Returns every cached `.gguf` model paired with its byte size. */
fun getCachedModels(): List<CachedModel> {
    return internalGetCachedModels()
}

/** Delete a cached model file and return the number of bytes freed. */
fun deleteCachedModel(modelPath: String): ULong {
    return internalDeleteCachedModel(modelPath)
}

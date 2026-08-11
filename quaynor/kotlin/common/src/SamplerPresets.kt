package ai.quaynor

import uniffi.quaynor.samplerPresetDefault
import uniffi.quaynor.samplerPresetDry
import uniffi.quaynor.samplerPresetGrammar
import uniffi.quaynor.samplerPresetGreedy
import uniffi.quaynor.samplerPresetJson
import uniffi.quaynor.samplerPresetTemperature
import uniffi.quaynor.samplerPresetTopK
import uniffi.quaynor.samplerPresetTopP

/**
 * Factory methods for common sampler configurations.
 *
 * ```kotlin
 * val sampler = SamplerPresets.temperature(0.7f)
 * val chat = Chat(model = model, sampler = sampler)
 * ```
 */
object SamplerPresets {
    fun default(): SamplerConfig = samplerPresetDefault()
    fun topK(topK: Int): SamplerConfig = samplerPresetTopK(topK)
    fun topP(topP: Float): SamplerConfig = samplerPresetTopP(topP)
    fun greedy(): SamplerConfig = samplerPresetGreedy()
    fun temperature(temperature: Float): SamplerConfig = samplerPresetTemperature(temperature)
    fun dry(): SamplerConfig = samplerPresetDry()
    fun json(): SamplerConfig = samplerPresetJson()
    fun grammar(grammar: String): SamplerConfig = samplerPresetGrammar(grammar)
}

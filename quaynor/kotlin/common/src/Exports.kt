package ai.quaynor

// Re-export uniffi types that are part of the public API so consumers
// only need to import from ai.quaynor.
typealias SamplerConfig = uniffi.quaynor.SamplerConfig
typealias Asset = uniffi.quaynor.Asset
typealias ToolCall = uniffi.quaynor.ToolCall
typealias CachedModel = uniffi.quaynor.CachedModel

/**
 * A message in the chat history.
 *
 * - [User] — a user message, optionally with image/audio assets
 * - [Assistant] — an assistant response, optionally with tool calls
 * - [System] — a system prompt
 * - [Tool] — the result returned by a tool invocation
 */
sealed class Message {
    data class User(val content: String, val assets: List<Asset> = emptyList()) : Message()
    data class Assistant(val content: String, val toolCalls: List<ToolCall>? = null) : Message()
    data class System(val content: String) : Message()
    data class Tool(val name: String, val content: String) : Message()

    companion object {
        internal fun fromUniFFI(msg: uniffi.quaynor.Message): Message = when (msg) {
            is uniffi.quaynor.Message.Message -> when (msg.role) {
                uniffi.quaynor.Role.USER -> User(msg.content, msg.assets)
                uniffi.quaynor.Role.ASSISTANT -> Assistant(msg.content)
                uniffi.quaynor.Role.SYSTEM -> System(msg.content)
                uniffi.quaynor.Role.TOOL -> Tool("", msg.content)
            }
            is uniffi.quaynor.Message.ToolCalls -> Assistant(msg.content, msg.toolCalls)
            is uniffi.quaynor.Message.ToolResp -> Tool(msg.name, msg.content)
        }

        internal fun toUniFFI(msg: Message): uniffi.quaynor.Message = when (msg) {
            is User -> uniffi.quaynor.Message.Message(uniffi.quaynor.Role.USER, msg.content, msg.assets)
            is Assistant -> msg.toolCalls?.let {
                uniffi.quaynor.Message.ToolCalls(uniffi.quaynor.Role.ASSISTANT, msg.content, it)
            } ?: uniffi.quaynor.Message.Message(uniffi.quaynor.Role.ASSISTANT, msg.content, emptyList())
            is System -> uniffi.quaynor.Message.Message(uniffi.quaynor.Role.SYSTEM, msg.content, emptyList())
            is Tool -> uniffi.quaynor.Message.ToolResp(uniffi.quaynor.Role.TOOL, msg.name, msg.content)
        }
    }
}

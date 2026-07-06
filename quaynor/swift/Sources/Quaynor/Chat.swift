import Foundation
import QuaynorFFI

public final class Chat: @unchecked Sendable {
    private var inner: RustChat?
    private var activeTools: [Tool]

    public init(
        model: Model,
        systemPrompt: String? = nil,
        contextSize: UInt32 = 4096,
        templateVariables: [String: Bool]? = nil,
        tools: [Tool]? = nil,
        sampler: SamplerConfig? = nil
    ) throws {
        let tools = tools ?? []
        let rustTools = try tools.map { try $0.requireInner() }
        self.inner = try RustChat(
            model: try model.requireInner(),
            systemPrompt: systemPrompt,
            contextSize: contextSize,
            templateVariables: templateVariables,
            tools: rustTools,
            sampler: sampler
        )
        self.activeTools = tools
    }

    public static func fromPath(
        modelPath: String,
        useGpu: Bool = true,
        projectionModelPath: String? = nil,
        systemPrompt: String? = nil,
        contextSize: UInt32 = 4096,
        templateVariables: [String: Bool]? = nil,
        tools: [Tool]? = nil,
        sampler: SamplerConfig? = nil,
        onDownloadProgress: ((UInt64, UInt64) -> Void)? = nil
    ) async throws -> Chat {
        let model = try await Model.load(
            modelPath: modelPath,
            useGpu: useGpu,
            projectionModelPath: projectionModelPath,
            onDownloadProgress: onDownloadProgress
        )
        return try Chat(
            model: model,
            systemPrompt: systemPrompt,
            contextSize: contextSize,
            templateVariables: templateVariables,
            tools: tools,
            sampler: sampler
        )
    }

    public func ask(_ message: String) throws -> TokenStream {
        let inner = try requireInner()
        return TokenStream(inner: inner.ask(message: message))
    }

    public func ask(_ prompt: Prompt) throws -> TokenStream {
        let inner = try requireInner()
        return TokenStream(inner: inner.askWithPrompt(parts: prompt.ffiParts))
    }

    public func stopGeneration() throws {
        try requireInner().stopGeneration()
    }

    public func resetContext(
        systemPrompt: String? = nil,
        tools: [Tool]? = nil
    ) async throws {
        let tools = tools ?? []
        let rustTools = try tools.map { try $0.requireInner() }
        try await requireInner().resetContext(systemPrompt: systemPrompt, tools: rustTools)
        activeTools = tools
    }

    public func resetHistory() async throws {
        try await requireInner().resetHistory()
    }

    public func getChatHistory() async throws -> [ChatMessage] {
        try await requireInner().getChatHistory().map(ChatMessage.fromInternal)
    }

    public func setChatHistory(_ messages: [ChatMessage]) async throws {
        try await requireInner().setChatHistory(messages: messages.map { $0.toInternal() })
    }

    public func getSystemPrompt() async throws -> String? {
        try await requireInner().getSystemPrompt()
    }

    public func setSystemPrompt(_ systemPrompt: String?) async throws {
        try await requireInner().setSystemPrompt(systemPrompt: systemPrompt)
    }

    public func setTools(_ tools: [Tool]) async throws {
        let rustTools = try tools.map { try $0.requireInner() }
        try await requireInner().setTools(tools: rustTools)
        activeTools = tools
    }

    public func setTemplateVariable(name: String, value: Bool) async throws {
        try await requireInner().setTemplateVariable(name: name, value: value)
    }

    public func getTemplateVariables() async throws -> [String: Bool] {
        try await requireInner().getTemplateVariables()
    }

    public func setSamplerConfig(_ sampler: SamplerConfig) async throws {
        try await requireInner().setSamplerConfig(sampler: sampler)
    }

    public func getSamplerConfig() async throws -> SamplerConfig {
        let json = try await requireInner().getSamplerConfigJson()
        return try SamplerConfig.fromJson(jsonStr: json)
    }

    public func getStats() async throws -> ChatStats {
        try await requireInner().getStats()
    }

    public func tokenize(message: String) async throws -> [Int32?] {
        try await requireInner().tokenize(message: message)
    }

    public func destroy() {
        inner = nil
        activeTools = []
    }

    fileprivate func requireInner() throws -> RustChat {
        guard let inner else {
            throw QuaynorBindingError.destroyedInstance(typeName: "Chat")
        }
        return inner
    }
}

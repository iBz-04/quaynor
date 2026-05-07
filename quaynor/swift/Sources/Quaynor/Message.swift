import Foundation
import QuaynorFFI

public enum ChatMessage: Sendable, Hashable {
    case message(role: Role, content: String, assets: [Asset] = [])
    case toolCalls(content: String, toolCalls: [ToolCall])
    case toolResponse(name: String, content: String)

    static func fromInternal(_ message: QuaynorFFI.Message) -> ChatMessage {
        switch message {
        case let .message(role, content, assets):
            return .message(role: role, content: content, assets: assets)
        case let .toolCalls(_, content, toolCalls):
            return .toolCalls(content: content, toolCalls: toolCalls)
        case let .toolResp(_, name, content):
            return .toolResponse(name: name, content: content)
        }
    }

    func toInternal() -> QuaynorFFI.Message {
        switch self {
        case let .message(role, content, assets):
            return .message(role: role, content: content, assets: assets)
        case let .toolCalls(content, toolCalls):
            return .toolCalls(role: .assistant, content: content, toolCalls: toolCalls)
        case let .toolResponse(name, content):
            return .toolResp(role: .tool, name: name, content: content)
        }
    }
}

import Foundation
import QuaynorFFI

public struct Prompt: Sendable, Hashable {
    public enum Part: Sendable, Hashable {
        case text(String)
        case image(path: String)
        case audio(path: String)
    }

    let ffiParts: [QuaynorFFI.PromptPart]

    public init(parts: [Part]) {
        self.ffiParts = parts.map { part in
            switch part {
            case let .text(content):
                return .text(content: content)
            case let .image(path):
                return .image(path: path)
            case let .audio(path):
                return .audio(path: path)
            }
        }
    }

    public static func text(_ content: String) -> Part {
        .text(content)
    }

    public static func image(_ path: String) -> Part {
        .image(path: path)
    }

    public static func audio(_ path: String) -> Part {
        .audio(path: path)
    }
}

import Foundation

public enum QuaynorBindingError: Error, LocalizedError, Sendable {
    case destroyedInstance(typeName: String)
    case invalidToolArguments(String)
    case invalidToolResponse(String)
    case invalidCrossEncoderResponse

    public var errorDescription: String? {
        switch self {
        case let .destroyedInstance(typeName):
            return "\(typeName) has already been destroyed and can no longer be used."
        case let .invalidToolArguments(message):
            return message
        case let .invalidToolResponse(message):
            return message
        case .invalidCrossEncoderResponse:
            return "CrossEncoder returned malformed ranked documents JSON."
        }
    }
}

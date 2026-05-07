import Foundation
import QuaynorFFI

public final class Encoder: @unchecked Sendable {
    private var inner: RustEncoder?

    public init(model: Model, contextSize: UInt32? = nil) throws {
        self.inner = RustEncoder(model: try model.requireInner(), contextSize: contextSize)
    }

    public static func fromPath(
        modelPath: String,
        useGpu: Bool = true,
        contextSize: UInt32? = nil
    ) async throws -> Encoder {
        let model = try await Model.load(modelPath: modelPath, useGpu: useGpu)
        return try Encoder(model: model, contextSize: contextSize)
    }

    public func encode(_ text: String) async throws -> [Float] {
        try await requireInner().encode(text: text)
    }

    public func destroy() {
        inner = nil
    }

    fileprivate func requireInner() throws -> RustEncoder {
        guard let inner else {
            throw QuaynorBindingError.destroyedInstance(typeName: "Encoder")
        }
        return inner
    }
}

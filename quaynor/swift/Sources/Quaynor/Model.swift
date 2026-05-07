import Foundation
import QuaynorFFI

public final class Model: @unchecked Sendable {
    private var inner: RustModel?

    init(inner: RustModel) {
        self.inner = inner
    }

    public static func load(
        modelPath: String,
        useGpu: Bool = true,
        projectionModelPath: String? = nil
    ) async throws -> Model {
        let inner = try await loadModel(
            modelPath: modelPath,
            useGpu: useGpu,
            projectionModelPath: projectionModelPath
        )
        return Model(inner: inner)
    }

    public func destroy() {
        inner = nil
    }

    func requireInner() throws -> RustModel {
        guard let inner else {
            throw QuaynorBindingError.destroyedInstance(typeName: "Model")
        }
        return inner
    }
}

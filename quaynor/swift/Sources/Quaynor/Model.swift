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
        projectionModelPath: String? = nil,
        onDownloadProgress: ((UInt64, UInt64) -> Void)? = nil
    ) async throws -> Model {
        let callback = onDownloadProgress.map { DownloadProgressCallbackImpl($0) }
        let inner = try await loadModel(
            modelPath: modelPath,
            useGpu: useGpu,
            projectionModelPath: projectionModelPath,
            onDownloadProgress: callback
        )
        return Model(inner: inner)
    }

    public static func downloadModel(
        modelPath: String,
        headers: [String: String]? = nil,
        onDownloadProgress: ((UInt64, UInt64) -> Void)? = nil
    ) async throws -> String {
        let callback = onDownloadProgress.map { DownloadProgressCallbackImpl($0) }
        return try await QuaynorFFI.downloadModel(
            modelPath: modelPath,
            headers: headers,
            onDownloadProgress: callback
        )
    }

    public static func getCachedModels() throws -> [CachedModel] {
        try QuaynorFFI.getCachedModels()
    }

    public var maxCtx: UInt32 {
        get throws {
            try requireInner().maxCtx()
        }
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

private final class DownloadProgressCallbackImpl: @unchecked Sendable, RustDownloadProgressCallback {
    private let handler: (UInt64, UInt64) -> Void

    init(_ handler: @escaping (UInt64, UInt64) -> Void) {
        self.handler = handler
    }

    func onDownloadProgress(downloaded: UInt64, total: UInt64) {
        handler(downloaded, total)
    }
}

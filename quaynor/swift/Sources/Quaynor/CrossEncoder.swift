import Foundation
import QuaynorFFI

public final class CrossEncoder: @unchecked Sendable {
    private var inner: RustCrossEncoder?

    public init(model: Model, contextSize: UInt32? = nil) throws {
        self.inner = try RustCrossEncoder(model: try model.requireInner(), contextSize: contextSize)
    }

    public static func fromPath(
        modelPath: String,
        useGpu: Bool = true,
        contextSize: UInt32? = nil
    ) async throws -> CrossEncoder {
        let model = try await Model.load(modelPath: modelPath, useGpu: useGpu)
        return try CrossEncoder(model: model, contextSize: contextSize)
    }

    public func rank(query: String, documents: [String]) async throws -> [Float] {
        try await requireInner().rank(query: query, documents: documents)
    }

    public func rankAndSort(
        query: String,
        documents: [String]
    ) async throws -> [(document: String, score: Float)] {
        let json = try await requireInner().rankAndSortJson(query: query, documents: documents)
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
        guard let rows = object as? [[Any]] else {
            throw QuaynorBindingError.invalidCrossEncoderResponse
        }

        return try rows.map { row in
            guard row.count == 2, let document = row[0] as? String else {
                throw QuaynorBindingError.invalidCrossEncoderResponse
            }
            guard let score = row[1] as? NSNumber else {
                throw QuaynorBindingError.invalidCrossEncoderResponse
            }
            return (document: document, score: score.floatValue)
        }
    }

    public func destroy() {
        inner = nil
    }

    fileprivate func requireInner() throws -> RustCrossEncoder {
        guard let inner else {
            throw QuaynorBindingError.destroyedInstance(typeName: "CrossEncoder")
        }
        return inner
    }
}

import Foundation
import QuaynorFFI

public final class TokenStream: AsyncSequence, @unchecked Sendable {
    public typealias Element = String

    private var inner: RustTokenStream?

    init(inner: RustTokenStream) {
        self.inner = inner
    }

    public func nextToken() async throws -> String? {
        guard let inner else {
            throw QuaynorBindingError.destroyedInstance(typeName: "TokenStream")
        }
        return await inner.nextToken()
    }

    public func completed() async throws -> String {
        guard let inner else {
            throw QuaynorBindingError.destroyedInstance(typeName: "TokenStream")
        }
        return try await inner.completed()
    }

    public func destroy() {
        inner = nil
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private let stream: TokenStream

        fileprivate init(stream: TokenStream) {
            self.stream = stream
        }

        public mutating func next() async throws -> String? {
            try await stream.nextToken()
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(stream: self)
    }
}

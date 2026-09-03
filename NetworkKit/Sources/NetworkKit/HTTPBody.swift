import Foundation

// MARK: - HTTP Body

public enum HTTPBody: Sendable {
    case json(Encodable & Sendable)
    case data(Data)

    public func encode() throws -> (data: Data, contentType: String) {
        switch self {
        case .json(let encodable):
            return try encodeJSON(encodable)
        case .data(let data):
            return (data, "application/octet-stream")
        }
    }

    private func encodeJSON(_ encodable: Encodable & Sendable) throws -> (Data, String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            return (try encoder.encode(AnyEncodable(encodable)), "application/json")
        } catch {
            throw NetworkError.encodingError(error)
        }
    }
}

// MARK: - Type-Erased Encodable

private struct AnyEncodable: Encodable, Sendable {
    private let _encode: @Sendable (Encoder) throws -> Void

    init<T: Encodable & Sendable>(_ wrapped: T) {
        _encode = { try wrapped.encode(to: $0) }
    }

    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}

import Foundation

// MARK: - HTTP Body

public enum HTTPBody: Sendable {
    case json(Encodable & Sendable)
    case data(Data)
    case multipart(MultipartFormData)
    case formURLEncoded([String: String])

    public func encode() throws -> (data: Data, contentType: String) {
        switch self {
        case .json(let encodable):
            return try encodeJSON(encodable)
        case .data(let data):
            return (data, "application/octet-stream")
        case .multipart(let formData):
            let data = try formData.encode()
            return (data, "multipart/form-data; boundary=\(formData.boundary)")
        case .formURLEncoded(let params):
            let body = params
                .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
                .joined(separator: "&")
            guard let data = body.data(using: .utf8) else {
                throw NetworkError.encodingError(NSError(domain: "FormEncodingError", code: -1))
            }
            return (data, "application/x-www-form-urlencoded")
        }
    }

    private func encodeJSON(_ encodable: Encodable & Sendable) throws -> (Data, String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(AnyEncodable(encodable))
        return (data, "application/json")
    }
}

// MARK: - Multipart Form Data

public struct MultipartFormData: Sendable {
    public let boundary: String
    private let parts: [Part]

    public init(boundary: String = UUID().uuidString) {
        self.boundary = boundary
        self.parts = []
    }

    private init(boundary: String, parts: [Part]) {
        self.boundary = boundary
        self.parts = parts
    }

    public func append(name: String, value: String) -> MultipartFormData {
        MultipartFormData(boundary: boundary, parts: parts + [.text(name: name, value: value)])
    }

    public func append(name: String, fileName: String, fileData: Data, mimeType: String) -> MultipartFormData {
        MultipartFormData(boundary: boundary, parts: parts + [.file(name: name, fileName: fileName, data: fileData, mimeType: mimeType)])
    }

    func encode() throws -> Data {
        var data = Data()
        for part in parts {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            switch part {
            case .text(let name, let value):
                data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
                data.append("\(value)\r\n".data(using: .utf8)!)
            case .file(let name, let fileName, let fileData, let mimeType):
                data.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
                data.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
                data.append(fileData)
                data.append("\r\n".data(using: .utf8)!)
            }
        }
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return data
    }

    enum Part: Sendable {
        case text(name: String, value: String)
        case file(name: String, fileName: String, data: Data, mimeType: String)
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

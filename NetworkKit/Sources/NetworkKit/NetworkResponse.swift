import Foundation

// MARK: - Network Response

public struct NetworkResponse: Sendable {
    public let data: Data
    public let urlResponse: URLResponse
    public let statusCode: Int
    public let headers: [String: String]

    public init(data: Data, urlResponse: URLResponse) {
        self.data = data
        self.urlResponse = urlResponse
        self.statusCode = (urlResponse as? HTTPURLResponse)?.statusCode ?? 0
        if let http = urlResponse as? HTTPURLResponse {
            var h: [String: String] = [:]
            for (k, v) in http.allHeaderFields {
                if let key = k as? String, let val = v as? String { h[key] = val }
            }
            self.headers = h
        } else {
            self.headers = [:]
        }
    }

    public func header(forKey key: String) -> String? { headers[key] }
    public var isSuccessful: Bool { (200...299).contains(statusCode) }

    public func decode<T: Decodable>(_ type: T.Type, using decoder: JSONDecoder? = nil) throws -> T {
        let d = decoder ?? {
            let dec = JSONDecoder()
            dec.keyDecodingStrategy = .convertFromSnakeCase
            dec.dateDecodingStrategy = .iso8601
            return dec
        }()
        return try d.decode(type, from: data)
    }

    public func stringValue(encoding: String.Encoding = .utf8) -> String? {
        String(data: data, encoding: encoding)
    }
}

import Foundation

// MARK: - Network Errors

public enum NetworkError: Error, Sendable, LocalizedError {
    case invalidURL(String? = nil)
    case noData
    case timeout(duration: TimeInterval? = nil)
    case cancelled
    case decodingError(Error, data: Data? = nil)
    case encodingError(Error)
    case httpError(statusCode: Int, message: String, data: Data? = nil)
    case networkError(Error)
    case unauthorized(message: String? = nil)
    case forbidden(message: String? = nil)
    case notFound(resource: String? = nil)
    case rateLimited(retryAfter: TimeInterval? = nil)
    case serverError(statusCode: Int? = nil)
    case retryRequired
    case sslPinningFailed
    case requestTooLarge
    case badRequest(message: String? = nil)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):        return url.map { "Invalid URL: \($0)" } ?? "Invalid URL"
        case .noData:                     return "No data received from server"
        case .timeout(let d):             return d.map { "Request timed out after \($0)s" } ?? "Request timed out"
        case .cancelled:                  return "Request was cancelled"
        case .decodingError(let e, let d):
            var msg = "Failed to decode response: \(e.localizedDescription)"
            if let d, let s = String(data: d, encoding: .utf8) { msg += "\nData: \(s)" }
            return msg
        case .encodingError(let e):       return "Failed to encode request: \(e.localizedDescription)"
        case .httpError(let c, let m, _): return "HTTP \(c): \(m)"
        case .networkError(let e):        return "Network error: \(e.localizedDescription)"
        case .unauthorized(let m):        return m ?? "Unauthorized"
        case .forbidden(let m):           return m ?? "Forbidden"
        case .notFound(let r):            return r.map { "Not found: \($0)" } ?? "Not found"
        case .rateLimited(let r):         return r.map { "Rate limited — retry after \($0)s" } ?? "Rate limited"
        case .serverError(let c):         return c.map { "Server error (\($0))" } ?? "Server error"
        case .retryRequired:              return "Request should be retried"
        case .sslPinningFailed:           return "SSL pinning validation failed"
        case .requestTooLarge:            return "Request payload too large"
        case .badRequest(let m):          return m ?? "Bad request"
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .timeout, .networkError, .rateLimited, .serverError, .retryRequired: return true
        case .httpError(let c, _, _): return [408, 429, 500, 502, 503, 504].contains(c)
        default: return false
        }
    }

    public var statusCode: Int? {
        switch self {
        case .httpError(let c, _, _):  return c
        case .unauthorized:            return 401
        case .forbidden:               return 403
        case .notFound:                return 404
        case .rateLimited:             return 429
        case .serverError(let c):      return c ?? 500
        case .badRequest:              return 400
        case .requestTooLarge:         return 413
        default:                       return nil
        }
    }
}

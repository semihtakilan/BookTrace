import Foundation

// MARK: - Authentication Interceptor
// Uses optional token provider — if no token is available, the header is simply omitted.
// This allows unauthenticated endpoints (e.g. login) to work without throwing.
public struct AuthenticationInterceptor: RequestInterceptor {
    private let tokenProvider: @Sendable () async -> String?

    public init(tokenProvider: @Sendable @escaping () async -> String?) {
        self.tokenProvider = tokenProvider
    }

    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        var req = request
        if let token = await tokenProvider() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }
}

// MARK: - Logging Interceptor

public struct LoggingInterceptor: RequestInterceptor, ResponseInterceptor {
    private let logger: NetworkLogger

    public init(
        logLevel: LogLevel = .debug,
        includeHeaders: Bool = true,
        includeBody: Bool = true,
        includeResponse: Bool = true
    ) {
        self.logger = NetworkLogger(
            logLevel: logLevel,
            includeHeaders: includeHeaders,
            includeBody: includeBody,
            includeResponse: includeResponse
        )
    }

    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        await logger.logRequest(request)
        return request
    }

    public func intercept(_ response: NetworkResponse) async throws -> NetworkResponse {
        await logger.logResponse(response, data: response.data)
        return response
    }
}

// MARK: - Custom Headers Interceptor

public struct CustomHeadersInterceptor: RequestInterceptor {
    private let headers: [String: String]
    private let overrideExisting: Bool

    public init(headers: [String: String], overrideExisting: Bool = false) {
        self.headers = headers
        self.overrideExisting = overrideExisting
    }

    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        var req = request
        for (key, value) in headers {
            if overrideExisting || req.value(forHTTPHeaderField: key) == nil {
                req.setValue(value, forHTTPHeaderField: key)
            }
        }
        return req
    }
}

// MARK: - Request ID Interceptor

public struct RequestIDInterceptor: RequestInterceptor {
    public init() {}

    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        var req = request
        req.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        return req
    }
}

// MARK: - Response Validation Interceptor

public struct ResponseValidationInterceptor: ResponseInterceptor {
    private let validStatusCodes: Range<Int>

    public init(validStatusCodes: Range<Int> = 200..<300) {
        self.validStatusCodes = validStatusCodes
    }

    public func intercept(_ response: NetworkResponse) async throws -> NetworkResponse {
        guard validStatusCodes.contains(response.statusCode) else {
            throw NetworkError.httpError(
                statusCode: response.statusCode,
                message: HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
            )
        }
        return response
    }
}

// MARK: - Cache Control Interceptor

public struct CacheControlInterceptor: RequestInterceptor {
    public enum CachePolicy: Sendable {
        case noCache
        case noStore
        case maxAge(TimeInterval)
        case custom(String)

        var headerValue: String {
            switch self {
            case .noCache:         return "no-cache"
            case .noStore:         return "no-store"
            case .maxAge(let s):   return "max-age=\(Int(s))"
            case .custom(let v):   return v
            }
        }
    }

    private let cachePolicy: CachePolicy

    public init(cachePolicy: CachePolicy) { self.cachePolicy = cachePolicy }

    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        var req = request
        req.setValue(cachePolicy.headerValue, forHTTPHeaderField: "Cache-Control")
        return req
    }
}

// MARK: - User Agent Interceptor

public struct UserAgentInterceptor: RequestInterceptor {
    private let userAgent: String

    public init(appName: String, appVersion: String, systemInfo: String) {
        self.userAgent = "\(appName)/\(appVersion) (\(systemInfo))"
    }

    public init(userAgent: String) {
        self.userAgent = userAgent
    }

    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        var req = request
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return req
    }
}

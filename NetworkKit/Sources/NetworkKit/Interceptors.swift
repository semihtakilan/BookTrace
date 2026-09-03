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

// MARK: - Request ID Interceptor

public struct RequestIDInterceptor: RequestInterceptor {
    public init() {}

    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        var req = request
        req.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
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

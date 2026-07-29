import Foundation

// MARK: - Network Configuration

public struct NetworkConfiguration: Sendable {
    public let environment: APIEnvironment
    public let baseURL: URL
    public let defaultHeaders: [String: String]
    public let timeout: TimeInterval
    public let retryCount: Int
    public let retryDelay: TimeInterval
    public let logLevel: LogLevel
    public let enableSSLPinning: Bool
    public let apiVersion: String

    public init(
        environment: APIEnvironment,
        customBaseURL: URL? = nil,
        defaultHeaders: [String: String] = [:],
        timeout: TimeInterval? = nil,
        retryCount: Int? = nil,
        retryDelay: TimeInterval = 1.0,
        logLevel: LogLevel? = nil,
        enableSSLPinning: Bool = false,
        apiVersion: String = "v1"
    ) {
        self.environment = environment
        self.baseURL = customBaseURL ?? environment.baseURL
        self.timeout = timeout ?? environment.timeout
        self.retryCount = retryCount ?? environment.retryCount
        self.retryDelay = retryDelay
        self.logLevel = logLevel ?? environment.logLevel
        self.enableSSLPinning = enableSSLPinning
        self.apiVersion = apiVersion

        var headers: [String: String] = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        for (key, value) in defaultHeaders { headers[key] = value }
        self.defaultHeaders = headers
    }

    public static func development(customHeaders: [String: String] = [:]) -> NetworkConfiguration {
        NetworkConfiguration(environment: .development, defaultHeaders: customHeaders)
    }

    public static func production(customHeaders: [String: String] = [:]) -> NetworkConfiguration {
        NetworkConfiguration(environment: .production, defaultHeaders: customHeaders)
    }

    public static func testing(customBaseURL: URL? = nil) -> NetworkConfiguration {
        NetworkConfiguration(environment: .testing, customBaseURL: customBaseURL)
    }
}

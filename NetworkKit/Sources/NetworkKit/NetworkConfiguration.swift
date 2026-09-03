import Foundation

// MARK: - Network Configuration

public struct NetworkConfiguration: Sendable {
    public let environment: APIEnvironment
    public let defaultHeaders: [String: String]
    public let timeout: TimeInterval
    public let retryCount: Int
    public let retryDelay: TimeInterval
    public let logLevel: LogLevel

    public init(
        environment: APIEnvironment,
        defaultHeaders: [String: String] = [:],
        timeout: TimeInterval? = nil,
        retryCount: Int? = nil,
        retryDelay: TimeInterval = 1.0,
        logLevel: LogLevel? = nil
    ) {
        self.environment = environment
        self.timeout = timeout ?? environment.timeout
        self.retryCount = retryCount ?? environment.retryCount
        self.retryDelay = retryDelay
        self.logLevel = logLevel ?? environment.logLevel

        var headers: [String: String] = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        for (key, value) in defaultHeaders { headers[key] = value }
        self.defaultHeaders = headers
    }
}

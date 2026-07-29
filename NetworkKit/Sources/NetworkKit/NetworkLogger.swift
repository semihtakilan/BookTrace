import Foundation

// MARK: - Network Logger

public actor NetworkLogger {
    private let logLevel: LogLevel
    private let includeHeaders: Bool
    private let includeBody: Bool
    private let includeResponse: Bool

    public init(
        logLevel: LogLevel = .debug,
        includeHeaders: Bool = true,
        includeBody: Bool = true,
        includeResponse: Bool = true
    ) {
        self.logLevel = logLevel
        self.includeHeaders = includeHeaders
        self.includeBody = includeBody
        self.includeResponse = includeResponse
    }

    public func logRequest(_ request: URLRequest) {
        guard logLevel.rawValue >= LogLevel.info.rawValue else { return }
        var logs: [String] = []
        logs.append("┌─────────────────────────────────────────────────────────────")
        logs.append("│ 🚀 REQUEST")
        logs.append("├─────────────────────────────────────────────────────────────")
        logs.append("│ \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "Unknown URL")")
        if includeHeaders, let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            logs.append("├─────────────────────────────────────────────────────────────")
            logs.append("│ 📋 HEADERS:")
            headers.sorted(by: { $0.key < $1.key }).forEach { logs.append("│   \($0.key): \($0.value)") }
        }
        if includeBody, let body = request.httpBody {
            logs.append("├─────────────────────────────────────────────────────────────")
            logs.append("│ 📦 BODY:")
            if let obj = try? JSONSerialization.jsonObject(with: body),
               let pretty = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted),
               let str = String(data: pretty, encoding: .utf8) {
                str.split(separator: "\n").forEach { logs.append("│   \($0)") }
            } else if let str = String(data: body, encoding: .utf8) {
                logs.append("│   \(str)")
            }
        }
        logs.append("└─────────────────────────────────────────────────────────────")
        print(logs.joined(separator: "\n"))
    }

    public func logResponse(_ response: NetworkResponse, data: Data) {
        guard logLevel.rawValue >= LogLevel.info.rawValue else { return }
        let emoji = response.isSuccessful ? "✅" : "❌"
        var logs: [String] = []
        logs.append("┌─────────────────────────────────────────────────────────────")
        logs.append("│ \(emoji) RESPONSE — HTTP \(response.statusCode)")
        if includeResponse {
            logs.append("├─────────────────────────────────────────────────────────────")
            logs.append("│ 📦 BODY (\(data.count) bytes):")
            if let obj = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted),
               let str = String(data: pretty, encoding: .utf8) {
                str.split(separator: "\n").forEach { logs.append("│   \($0)") }
            } else if let str = String(data: data, encoding: .utf8) {
                logs.append("│   \(str.prefix(500))")
            }
        }
        logs.append("└─────────────────────────────────────────────────────────────")
        print(logs.joined(separator: "\n"))
    }

    public func logError(_ error: Error, for request: URLRequest) {
        guard logLevel.rawValue >= LogLevel.error.rawValue else { return }
        print("┌─────────────────────────────────────────────────────────────")
        print("│ ⛔ ERROR — \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "?")")
        print("│ \(error.localizedDescription)")
        print("└─────────────────────────────────────────────────────────────")
    }
}

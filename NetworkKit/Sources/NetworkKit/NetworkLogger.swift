//
//  NetworkLogger.swift
//  NetworkKit
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation
import os

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
        var details = [Self.redactedURL(request.url)]
        if includeHeaders, let headers = request.allHTTPHeaderFields {
            details.append(contentsOf: headers.sorted { $0.key < $1.key }.map {
                "\($0.key): \(Self.isCredential($0.key) ? "<redacted>" : $0.value)"
            })
        }
        if includeBody, let body = request.httpBody {
            details.append(String(data: body, encoding: .utf8) ?? "<binary body: \(body.count) bytes>")
        }
        emit(event: "REQUEST \(request.httpMethod ?? "GET")", details: details.joined(separator: "\n"), type: .info)
    }

    public func logResponse(_ response: NetworkResponse, data: Data) {
        guard logLevel.rawValue >= LogLevel.info.rawValue else { return }
        let body = includeResponse ? String(data: data, encoding: .utf8) ?? "<binary body>" : ""
        emit(event: "RESPONSE HTTP \(response.statusCode) (\(data.count) bytes)", details: body, type: .info)
    }

    public func logError(_ error: Error, for request: URLRequest) {
        guard logLevel.rawValue >= LogLevel.error.rawValue else { return }
        // Error descriptions can contain the original URL, including credentials.
        var message = error.localizedDescription
        if let url = request.url {
            message = message.replacingOccurrences(of: url.absoluteString, with: Self.redactedURL(url))
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let secrets = (components?.queryItems ?? []).filter { Self.isCredential($0.name) }.compactMap(\.value)
                + [components?.user, components?.password].compactMap { $0 }
            for secret in secrets where !secret.isEmpty {
                message = message.replacingOccurrences(of: secret, with: "<redacted>")
            }
        }
        emit(event: "NETWORK ERROR", details: "\(Self.redactedURL(request.url))\n\(message)", type: .error)
    }

    static func redactedURL(_ url: URL?) -> String {
        guard let url, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return "<unknown URL>"
        }
        components.user = nil
        components.password = nil
        components.fragment = nil
        components.queryItems = components.queryItems?.map { item in
            URLQueryItem(name: item.name, value: isCredential(item.name) ? "<redacted>" : item.value)
        }
        return components.string ?? "<invalid URL>"
    }

    static func isCredential(_ name: String) -> Bool {
        let normalized = name.lowercased().filter { $0.isLetter || $0.isNumber }
        return ["key", "apikey", "xapikey", "authorization", "proxyauthorization", "cookie", "setcookie",
                "token", "accesstoken", "refreshtoken", "idtoken", "password", "clientsecret", "secret", "signature"].contains(normalized)
    }

    private func emit(event: String, details: String, type: OSLogType) {
        // Keep endpoint data, headers, bodies, and error descriptions private.
        // URL/header credentials are also removed before reaching the log system.
        if #available(macOS 11.0, iOS 14.0, *) {
            let logger = Logger(subsystem: "com.semihtakilan.BookTrace.NetworkKit", category: "network")
            logger.log(level: type, "\(event, privacy: .public)\n\(details, privacy: .private)")
        } else {
            let log = OSLog(subsystem: "com.semihtakilan.BookTrace.NetworkKit", category: "network")
            os_log("%{public}@\n%{private}@", log: log, type: type, event, details)
        }
    }
}

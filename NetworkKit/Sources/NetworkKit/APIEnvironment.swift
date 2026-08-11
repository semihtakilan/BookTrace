//
//  APIEnvironment.swift
//  NetworkKit
//
//  Created by Semih TAKILAN on 29.07.2026.
//

import Foundation

// MARK: - API Environment
public enum APIEnvironment: String, CaseIterable, Sendable {
    case development = "dev"
    case staging = "staging"
    case production = "prod"
    case testing = "test"

    public var displayName: String {
        switch self {
        case .development: return "Development"
        case .staging:     return "Staging"
        case .production:  return "Production"
        case .testing:     return "Testing"
        }
    }

    public var baseURL: URL {
        URL(string: "https://www.googleapis.com/books/v1")!
    }

    public var timeout: TimeInterval {
        switch self {
        case .development, .testing: return 60.0
        case .staging:               return 30.0
        case .production:            return 15.0
        }
    }

    public var retryCount: Int {
        switch self {
        case .development, .staging, .production: return 3
        case .testing:                            return 1
        }
    }

    public var logLevel: LogLevel {
        switch self {
        case .development, .testing: return .verbose
        case .staging:               return .info
        case .production:            return .error
        }
    }
}

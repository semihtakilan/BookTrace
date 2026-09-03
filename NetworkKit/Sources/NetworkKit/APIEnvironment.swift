//
//  APIEnvironment.swift
//  NetworkKit
//
//  Created by Semih TAKILAN on 29.07.2026.
//

import Foundation

// MARK: - API Environment

/// Ağ katmanının çalışma kipi: zaman aşımı, tekrar sayısı ve log seviyesi.
///
/// Ortam bir taban adres taşımıyor — her `Endpoint` kendi `baseURL`'ini
/// bildirir. Önceden buradaki `baseURL` dört ortam için de aynı adresi
/// döndürüyordu ve zaten her endpoint tarafından geçersiz kılınıyordu.
public enum APIEnvironment: String, CaseIterable, Sendable {
    case development = "dev"
    case staging = "staging"
    case production = "prod"
    case testing = "test"

    /// Derleme kipine göre seçilen ortam.
    public static var current: APIEnvironment {
        #if DEBUG
        .development
        #else
        .production
        #endif
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

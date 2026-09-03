//
//  UserFacingError.swift
//  ErrorPresentation
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Foundation
import Models
import NetworkKit
import SwiftUI

/// Kullanıcıya gösterilebilecek hata.
///
/// Ekranlara ham `Error` sızdırmamak için tek geçit burasıdır. Foundation ve
/// NetworkKit'in `localizedDescription`'ları ("The operation couldn't be
/// completed. (Swift.CancellationError error 1.)" gibi) kullanıcıya hiçbir şey
/// anlatmıyor; her hata burada tanınan bir duruma indirgenir.
nonisolated enum UserFacingError: Equatable, Sendable {
    case offline
    case timedOut
    case quotaExceeded(hasAPIKey: Bool)
    case serviceUnavailable
    case unexpectedResponse
    case bookNotFound
    case notInLibrary
    case cameraUnavailable
    case unknown

    /// İptal edilmiş işler hata değildir — kullanıcı sekme değiştirdiğinde veya
    /// yazmaya devam ettiğinde önceki istek iptal olur. Bu durumda `nil` döner
    /// ve çağıran taraf hiçbir şey göstermez.
    init?(_ error: Error) {
        if UserFacingError.isCancellation(error) { return nil }

        switch error {
        case let googleBooksError as GoogleBooksServiceError:
            switch googleBooksError {
            case .bookNotFound:               self = .bookNotFound
            case .quotaExceeded(let hasKey):  self = .quotaExceeded(hasAPIKey: hasKey)
            case .regionUnavailable:          self = .serviceUnavailable
            case .unreadableResponse:         self = .unexpectedResponse
            }

        case is CacheFirstBookSearchingError:
            self = .bookNotFound

        case is LocalLibraryRepositoryError:
            self = .notInLibrary

        case is ScannerError:
            self = .cameraUnavailable

        case let networkError as NetworkError:
            self = UserFacingError.from(networkError)

        case let urlError as URLError:
            self = UserFacingError.from(urlError)

        default:
            self = .unknown
        }
    }

    private static func from(_ error: NetworkError) -> UserFacingError {
        if let statusCode = error.statusCode {
            switch statusCode {
            case 429, 403: return .quotaExceeded(hasAPIKey: GoogleBooksAPIKey.value != nil)
            case 404:      return .bookNotFound
            case 500...:   return .serviceUnavailable
            default:       break
            }
        }

        switch error {
        case .timeout:              return .timedOut
        case .decodingError:        return .unexpectedResponse
        case .networkError(let underlying):
            return (underlying as? URLError).map(from) ?? .unknown
        default:                    return .unknown
        }
    }

    private static func from(_ error: URLError) -> UserFacingError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost,
             .cannotFindHost, .cannotConnectToHost, .dataNotAllowed:
            return .offline
        case .timedOut:
            return .timedOut
        default:
            return .unknown
        }
    }

    /// İptal her katmanda farklı bir tip olarak geliyor; hepsini burada tanıyoruz.
    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let networkError = error as? NetworkError, case .cancelled = networkError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return (error as NSError).code == NSUserCancelledError
    }

    /// Ekranda gösterilen metin. String Catalog üzerinden çevrilir.
    var message: LocalizedStringKey {
        switch self {
        case .offline:
            "You appear to be offline. Check your connection and try again."
        case .timedOut:
            "The request took too long. Try again."
        case .quotaExceeded(let hasAPIKey):
            // Anahtarsız kalmak yalnızca geliştirme sırasında olabilir; dağıtılan
            // uygulamada anahtar Info.plist'ten geldiği için kullanıcı bu
            // yönlendirmeyi asla görmemeli.
            UserFacingError.isDebugBuild && !hasAPIKey
                ? "Google Books has hit its quota. Add your own API key to keep browsing."
                : "Google Books has hit its quota. Try again in a little while."
        case .serviceUnavailable:
            "Google Books is temporarily unavailable. Try again in a moment."
        case .unexpectedResponse:
            "Google Books returned something we couldn't read."
        case .bookNotFound:
            "We couldn't find that book."
        case .notInLibrary:
            "That book is no longer in your library."
        case .cameraUnavailable:
            "The camera isn't available right now."
        case .unknown:
            "Something went wrong. Please try again."
        }
    }

    private static var isDebugBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    /// Kullanıcının tekrar denemesi mantıklı mı — "Try again" butonu buna bakar.
    var isRetryable: Bool {
        switch self {
        case .offline, .timedOut, .serviceUnavailable, .quotaExceeded, .unknown: true
        case .unexpectedResponse, .bookNotFound, .notInLibrary, .cameraUnavailable: false
        }
    }
}

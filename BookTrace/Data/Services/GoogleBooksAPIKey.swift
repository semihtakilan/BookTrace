//
//  GoogleBooksAPIKey.swift
//  Services
//
//  Created by Semih TAKILAN on 07.08.2026.
//

import Foundation

/// Google Books API anahtarı.
///
/// `volumes` uç noktası teknik olarak anahtarsız da çağrılabilir, ancak bu
/// çağrılar Google'ın paylaşımlı anonim projesinin günlük kotasını kullanır ve
/// pratikte sürekli 429 döner. Anahtar Scheme environment değişkeninden veya
/// Info.plist'ten okunur; ikisi de yoksa istek yine denenir, hata mesajı
/// kullanıcıyı anahtar eklemeye yönlendirir.
/// `nonisolated`: yalnızca `ProcessInfo` ve `Bundle` okur, ikisi de thread-safe;
/// böylece ağ çağrılarını yapan aktör dışı bağlamdan da erişilebilir.
nonisolated enum GoogleBooksAPIKey {
    static var value: String? {
        let environmentValue = ProcessInfo.processInfo.environment["GOOGLE_BOOKS_API_KEY"]
        let infoPlistValue = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_BOOKS_API_KEY") as? String
        let candidate = environmentValue ?? infoPlistValue
        let normalized = candidate?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalized, !normalized.isEmpty, !normalized.hasPrefix("$(") else { return nil }
        return normalized
    }
}

enum GoogleBooksServiceError: LocalizedError {
    case bookNotFound
    case quotaExceeded(hasAPIKey: Bool)
    case regionUnavailable(String)
    case unreadableResponse

    var errorDescription: String? {
        switch self {
        case .bookNotFound:
            "This book could not be found on Google Books."
        case .quotaExceeded(let hasAPIKey):
            hasAPIKey
                ? "Google Books quota reached. Try again in a little while."
                : "Google Books quota reached. Add your own API key: Xcode → Scheme → Run → Arguments → Environment Variables → GOOGLE_BOOKS_API_KEY."
        case .regionUnavailable(let region):
            "Google Books did not respond for region \(region). Your device region may not match the country you are connecting from."
        case .unreadableResponse:
            "Google Books returned an unexpected response."
        }
    }
}

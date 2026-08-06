import Foundation

enum GoogleBooksAPIKey {
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
    case missingAPIKey

    var errorDescription: String? {
        "Google Books API anahtarı eksik. GOOGLE_BOOKS_API_KEY değerini Scheme environment veya Info.plist üzerinden ekleyin."
    }
}

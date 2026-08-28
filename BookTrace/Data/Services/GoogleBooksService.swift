//
//  GoogleBooksService.swift
//  Services
//
//  Created by Semih TAKILAN on 06.08.2026.
//

import Foundation
import Models
import NetworkKit

/// Google Books API'nin uygulama içindeki tek erişim noktası.
final class GoogleBooksService: BookSearching {
    private let networkService: any NetworkServiceProtocol

    init(networkService: any NetworkServiceProtocol) {
        self.networkService = networkService
    }

    func searchBooks(query: String, maxResults: Int) async throws -> [BookReference] {
        try await execute {
            GoogleBooksSearchEndpoint.search(query: query, maxResults: maxResults, apiKey: $0)
        }
    }

    func books(inSubject subject: String, maxResults: Int) async throws -> [BookReference] {
        try await execute {
            GoogleBooksSearchEndpoint.subject(subject, maxResults: maxResults, apiKey: $0)
        }
    }

    func findBook(isbn: String) async throws -> BookReference {
        let books = try await execute { GoogleBooksSearchEndpoint.isbn(isbn, apiKey: $0) }
        guard let book = books.first else {
            throw GoogleBooksServiceError.bookNotFound
        }
        return book
    }

    /// Anahtarı tek yerden geçirir ve kota hatalarını kullanıcıya anlamlı gelen
    /// bir mesaja çevirir; ham "HTTP 429" kimseye ne yapacağını söylemiyor.
    private func execute(
        _ makeEndpoint: (String?) -> GoogleBooksSearchEndpoint
    ) async throws -> [BookReference] {
        let apiKey = GoogleBooksAPIKey.value

        do {
            return try await networkService.execute(makeEndpoint(apiKey)).toBookReferences()
        } catch let error as NetworkError {
            switch error.statusCode {
            case 429, 403:
                throw GoogleBooksServiceError.quotaExceeded(hasAPIKey: apiKey != nil)
            case 503:
                throw GoogleBooksServiceError.regionUnavailable(GoogleBooksRegion.current)
            case nil where error.isDecodingFailure:
                // NetworkKit'in decode hatası tüm gövdeyi metne gömüyor; onu
                // kullanıcıya göstermek yerine loglarda bırakıyoruz.
                throw GoogleBooksServiceError.unreadableResponse
            default:
                throw error
            }
        }
    }
}

private extension NetworkError {
    var isDecodingFailure: Bool {
        if case .decodingError = self { return true }
        return false
    }
}

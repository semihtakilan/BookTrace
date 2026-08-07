//
//  GoogleBooksService.swift
//  BookTrace
//

import Models
import NetworkKit

/// Google Books API'nin uygulama içindeki tek erişim noktası.
final class GoogleBooksService: BookSearching {
    private let networkService: any NetworkServiceProtocol

    init(networkService: any NetworkServiceProtocol) {
        self.networkService = networkService
    }

    func searchBooks(query: String, maxResults: Int = 20) async throws -> [Book] {
        guard let apiKey = GoogleBooksAPIKey.value else {
            throw GoogleBooksServiceError.missingAPIKey
        }
        let response = try await networkService.execute(
            GoogleBooksSearchEndpoint(query: query, maxResults: maxResults, apiKey: apiKey)
        )
        return response.items
    }

    func findBook(isbn: String) async throws -> Book {
        let books = try await searchBooks(query: "isbn:\(isbn)", maxResults: 1)
        guard let book = books.first else { throw NetworkError.notFound() }
        return book
    }
}

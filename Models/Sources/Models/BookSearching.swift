//
//  BookSearching.swift
//  Models
//
//  Created by Semih TAKILAN on 06.08.2026.
//

import Foundation

public protocol BookSearching: Sendable {
    func searchBooks(query: String, maxResults: Int) async throws -> [Book]
    func findBook(isbn: String) async throws -> Book
}

public struct SearchBooksUseCase: Sendable {
    private let repository: any BookSearching

    public init(repository: any BookSearching) {
        self.repository = repository
    }

    /// Boş aramayı ağ isteğine çevirmeden sonuçsuz kabul eder.
    public func execute(query: String, maxResults: Int = 20) async throws -> [Book] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return [] }
        return try await repository.searchBooks(query: normalizedQuery, maxResults: maxResults)
    }
}

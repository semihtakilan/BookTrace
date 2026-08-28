//
//  CacheFirstBookSearching.swift
//  Models
//
//  Created by Semih TAKILAN on 07.08.2026.
//

import Foundation

public protocol BookSearchCaching: Sendable {
    func books(for key: String) -> [BookReference]?
    func store(_ books: [BookReference], for key: String)
}

/// Önce cache'e bakan, yoksa uzak kaynağa giden dekoratör.
///
/// `BookSearching`'i sarmaladığı için çağıran taraf cache'in varlığından habersizdir.
public struct CacheFirstBookSearching: BookSearching, Sendable {
    private let remote: any BookSearching
    private let cache: any BookSearchCaching

    public init(remote: any BookSearching, cache: any BookSearchCaching) {
        self.remote = remote
        self.cache = cache
    }

    public func searchBooks(query: String, maxResults: Int) async throws -> [BookReference] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await cached(key: "search:\(normalizedQuery.lowercased()):\(maxResults)") {
            try await remote.searchBooks(query: normalizedQuery, maxResults: maxResults)
        }
    }

    public func books(inSubject subject: String, maxResults: Int) async throws -> [BookReference] {
        let normalizedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await cached(key: "subject:\(normalizedSubject.lowercased()):\(maxResults)") {
            try await remote.books(inSubject: normalizedSubject, maxResults: maxResults)
        }
    }

    public func findBook(isbn: String) async throws -> BookReference {
        let normalizedISBN = isbn.trimmingCharacters(in: .whitespacesAndNewlines)
        let books = try await cached(key: "isbn:\(normalizedISBN)") {
            [try await remote.findBook(isbn: normalizedISBN)]
        }
        guard let book = books.first else {
            throw CacheFirstBookSearchingError.bookNotFound
        }
        return book
    }

    private func cached(
        key: String,
        fetch: () async throws -> [BookReference]
    ) async rethrows -> [BookReference] {
        if let cachedBooks = cache.books(for: key) {
            return cachedBooks
        }
        let books = try await fetch()
        cache.store(books, for: key)
        return books
    }
}

public enum CacheFirstBookSearchingError: LocalizedError {
    case bookNotFound

    public var errorDescription: String? {
        "The requested book could not be found."
    }
}

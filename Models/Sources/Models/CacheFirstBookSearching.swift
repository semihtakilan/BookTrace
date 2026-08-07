import Foundation

/// Book arama sonuçlarını saklayan altyapı sözleşmesi.
public protocol BookSearchCaching: Sendable {
    func books(for key: String) -> [Book]?
    func store(_ books: [Book], for key: String)
}

/// Ağ isteğini yalnızca cache'te güncel veri olmadığında yapan repository decorator'ı.
public struct CacheFirstBookSearching: BookSearching, Sendable {
    private let remote: any BookSearching
    private let cache: any BookSearchCaching

    public init(remote: any BookSearching, cache: any BookSearchCaching) {
        self.remote = remote
        self.cache = cache
    }

    public func searchBooks(query: String, maxResults: Int) async throws -> [Book] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = "search:\(normalizedQuery.lowercased()):\(maxResults)"

        if let cachedBooks = cache.books(for: key) {
            return cachedBooks
        }

        let books = try await remote.searchBooks(query: normalizedQuery, maxResults: maxResults)
        cache.store(books, for: key)
        return books
    }

    public func findBook(isbn: String) async throws -> Book {
        let books = try await searchBooks(query: "isbn:\(isbn)", maxResults: 1)
        guard let book = books.first else {
            throw CacheFirstBookSearchingError.bookNotFound
        }
        return book
    }
}

public enum CacheFirstBookSearchingError: LocalizedError {
    case bookNotFound

    public var errorDescription: String? {
        "The requested book could not be found."
    }
}

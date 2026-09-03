//
//  BookSearchingMocks.swift
//  ModelsTests
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Foundation
@testable import Models

func makeReference(id: String, title: String = "Swift", pageCount: Int? = nil) -> BookReference {
    BookReference(id: id, title: title, authors: ["Author"], pageCount: pageCount)
}

/// Sayaçları aktörle koruyor: `CachedBookSearching` tazelemeyi `Task.detached`
/// içinde yapıyor, yani çağrılar iki farklı görevden gelebiliyor.
actor BookSearchingMock: BookSearching {
    private let result: [BookReference]
    private(set) var receivedQuery: String?
    private(set) var searchCallCount = 0
    private(set) var subjectCallCount = 0
    private(set) var isbnCallCount = 0

    init(result: [BookReference] = [makeReference(id: "remote-1")]) {
        self.result = result
    }

    func searchBooks(query: String, maxResults: Int) async throws -> [BookReference] {
        searchCallCount += 1
        receivedQuery = query
        return result
    }

    func books(inSubject subject: String, maxResults: Int) async throws -> [BookReference] {
        subjectCallCount += 1
        return result
    }

    func findBook(isbn: String) async throws -> BookReference {
        isbnCallCount += 1
        guard let first = result.first else { throw CachedBookSearchingError.bookNotFound }
        return first
    }
}

/// Bellekte duran cache mağazası; tazelik penceresini test elle kurar.
actor BookCacheStoreMock: BookCacheStore {
    private struct Entry {
        var books: [BookReference]
        var isStale: Bool
    }

    private var entries: [String: Entry] = [:]
    private var singleBooks: [String: BookReference] = [:]
    private(set) var storeCallCount = 0

    func seed(_ books: [BookReference], for query: BookQuery, isStale: Bool = false) {
        entries[query.cacheKey] = Entry(books: books, isStale: isStale)
    }

    func storedBooks(for query: BookQuery) -> [BookReference]? {
        entries[query.cacheKey]?.books
    }

    func books(for query: BookQuery) async -> CachedBooks? {
        guard let entry = entries[query.cacheKey] else { return nil }
        return CachedBooks(books: entry.books, isStale: entry.isStale)
    }

    func store(_ books: [BookReference], for query: BookQuery) async {
        storeCallCount += 1
        entries[query.cacheKey] = Entry(books: books, isStale: false)
    }

    func book(id: String) async -> BookReference? {
        singleBooks[id]
    }

    func merge(_ book: BookReference) async {
        singleBooks[book.id] = singleBooks[book.id]?.merging(book) ?? book
    }

    func removeAll() async {
        entries.removeAll()
        singleBooks.removeAll()
    }
}

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

final class BookSearchingMock: BookSearching, @unchecked Sendable {
    let result: [BookReference]
    private(set) var receivedQuery: String?
    private(set) var receivedSubject: String?
    private(set) var receivedMaxResults: Int?
    private(set) var searchCallCount = 0
    private(set) var subjectCallCount = 0
    private(set) var isbnCallCount = 0

    init(result: [BookReference] = [makeReference(id: "remote-1")]) {
        self.result = result
    }

    func searchBooks(query: String, maxResults: Int) async throws -> [BookReference] {
        searchCallCount += 1
        receivedQuery = query
        receivedMaxResults = maxResults
        return result
    }

    func books(inSubject subject: String, maxResults: Int) async throws -> [BookReference] {
        subjectCallCount += 1
        receivedSubject = subject
        receivedMaxResults = maxResults
        return result
    }

    func findBook(isbn: String) async throws -> BookReference {
        isbnCallCount += 1
        guard let first = result.first else { throw CacheFirstBookSearchingError.bookNotFound }
        return first
    }
}

final class BookSearchCacheMock: BookSearchCaching, @unchecked Sendable {
    var values: [String: [BookReference]] = [:]
    private(set) var storeCallCount = 0

    func books(for key: String) -> [BookReference]? {
        values[key]
    }

    func store(_ books: [BookReference], for key: String) {
        storeCallCount += 1
        values[key] = books
    }
}

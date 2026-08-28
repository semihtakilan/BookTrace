//
//  CacheFirstBookSearchingTests.swift
//  ModelsTests
//
//  Created by Semih TAKILAN on 07.08.2026.
//

import Foundation
import Testing
@testable import Models

struct CacheFirstBookSearchingTests {

    @Test func searchGoesToRemoteAndStoresTheResultWhenNothingIsCached() async throws {
        let remote = BookSearchingMock()
        let cache = BookSearchCacheMock()
        let sut = CacheFirstBookSearching(remote: remote, cache: cache)

        let books = try await sut.searchBooks(query: " Swift ", maxResults: 10)

        #expect(remote.searchCallCount == 1)
        #expect(remote.receivedQuery == "Swift")
        #expect(books == remote.result)
        #expect(cache.values["search:swift:10"] == remote.result)
    }

    @Test func searchSkipsRemoteWhenTheQueryIsAlreadyCached() async throws {
        let remote = BookSearchingMock()
        let cache = BookSearchCacheMock()
        let cached = [makeReference(id: "cached-1", title: "Cached Swift")]
        cache.values["search:swift:10"] = cached
        let sut = CacheFirstBookSearching(remote: remote, cache: cache)

        let books = try await sut.searchBooks(query: "Swift", maxResults: 10)

        #expect(remote.searchCallCount == 0)
        #expect(cache.storeCallCount == 0)
        #expect(books == cached)
    }

    @Test func subjectShelvesUseTheirOwnCacheKey() async throws {
        let remote = BookSearchingMock()
        let cache = BookSearchCacheMock()
        let sut = CacheFirstBookSearching(remote: remote, cache: cache)

        _ = try await sut.books(inSubject: "History", maxResults: 15)
        _ = try await sut.books(inSubject: "History", maxResults: 15)

        #expect(remote.subjectCallCount == 1)
        #expect(cache.values["subject:history:15"] == remote.result)
        #expect(cache.values["search:history:15"] == nil)
    }

    @Test func isbnLookupIsCachedAndReturnsASingleBook() async throws {
        let remote = BookSearchingMock(result: [makeReference(id: "isbn-1")])
        let cache = BookSearchCacheMock()
        let sut = CacheFirstBookSearching(remote: remote, cache: cache)

        let first = try await sut.findBook(isbn: "9781234567897")
        let second = try await sut.findBook(isbn: "9781234567897")

        #expect(first.id == "isbn-1")
        #expect(second.id == "isbn-1")
        #expect(remote.isbnCallCount == 1)
    }

    @Test func isbnLookupThrowsWhenTheCachedEntryIsEmpty() async throws {
        let remote = BookSearchingMock()
        let cache = BookSearchCacheMock()
        cache.values["isbn:9780000000000"] = []
        let sut = CacheFirstBookSearching(remote: remote, cache: cache)

        await #expect(throws: CacheFirstBookSearchingError.self) {
            _ = try await sut.findBook(isbn: "9780000000000")
        }
    }
}

struct SearchBooksUseCaseTests {

    @Test func theUseCaseTrimsTheQueryBeforeCallingTheRepository() async throws {
        let repository = BookSearchingMock()
        let useCase = SearchBooksUseCase(repository: repository)

        let books = try await useCase.execute(query: "  swift  ", maxResults: 5)

        #expect(repository.receivedQuery == "swift")
        #expect(repository.receivedMaxResults == 5)
        #expect(books == repository.result)
    }

    @Test func anEmptyQueryNeverReachesTheRepository() async throws {
        let repository = BookSearchingMock()
        let useCase = SearchBooksUseCase(repository: repository)

        let books = try await useCase.execute(query: "   ")

        #expect(books.isEmpty)
        #expect(repository.searchCallCount == 0)
    }
}

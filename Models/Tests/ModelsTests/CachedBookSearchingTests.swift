//
//  CachedBookSearchingTests.swift
//  ModelsTests
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation
import Testing
@testable import Models

@Suite struct CachedBookSearchingTests {

    @Test func aCachedQueryIsAnsweredWithoutTouchingTheNetwork() async throws {
        let remote = BookSearchingMock()
        let store = BookCacheStoreMock()
        await store.seed([makeReference(id: "cached-1")], for: .search(text: "swift", maxResults: 20))

        let searching = CachedBookSearching(remote: remote, store: store)
        let books = try await searching.searchBooks(query: "swift", maxResults: 20)

        #expect(books.map(\.id) == ["cached-1"])
        #expect(await remote.searchCallCount == 0)
    }

    @Test func aMissGoesToTheNetworkAndIsWrittenBack() async throws {
        let remote = BookSearchingMock(result: [makeReference(id: "remote-1")])
        let store = BookCacheStoreMock()

        let searching = CachedBookSearching(remote: remote, store: store)
        let books = try await searching.searchBooks(query: "swift", maxResults: 20)

        #expect(books.map(\.id) == ["remote-1"])
        #expect(await remote.searchCallCount == 1)
        #expect(await store.storedBooks(for: .search(text: "swift", maxResults: 20))?.count == 1)
    }

    @Test func theQueryIsNormalisedSoSpacingAndCaseShareOneEntry() async throws {
        let remote = BookSearchingMock()
        let store = BookCacheStoreMock()
        await store.seed([makeReference(id: "cached-1")], for: .search(text: "swift", maxResults: 20))

        let searching = CachedBookSearching(remote: remote, store: store)
        let books = try await searching.searchBooks(query: "  Swift  ", maxResults: 20)

        #expect(books.map(\.id) == ["cached-1"])
        #expect(await remote.searchCallCount == 0)
    }

    /// Bayat veri kullanıcıyı bekletmemeli: cevap cache'ten gelir, tazeleme
    /// arkada yapılır. Beklemeden ölçemediğimiz için tazelemenin *sonucunu*
    /// bekliyoruz, cevabın kendisini değil.
    @Test func staleDataIsServedImmediatelyAndRefreshedInTheBackground() async throws {
        let remote = BookSearchingMock(result: [makeReference(id: "fresh-1")])
        let store = BookCacheStoreMock()
        let query = BookQuery.subject("history", maxResults: 15)
        await store.seed([makeReference(id: "stale-1")], for: query, isStale: true)

        let searching = CachedBookSearching(remote: remote, store: store)
        let books = try await searching.books(inSubject: "history", maxResults: 15)

        #expect(books.map(\.id) == ["stale-1"])

        try await confirmEventually { await store.storedBooks(for: query)?.map(\.id) == ["fresh-1"] }
        #expect(await remote.subjectCallCount == 1)
    }

    @Test func aFreshEntryIsNotRefreshed() async throws {
        let remote = BookSearchingMock()
        let store = BookCacheStoreMock()
        let query = BookQuery.subject("history", maxResults: 15)
        await store.seed([makeReference(id: "cached-1")], for: query, isStale: false)

        let searching = CachedBookSearching(remote: remote, store: store)
        _ = try await searching.books(inSubject: "history", maxResults: 15)

        try await Task.sleep(for: .milliseconds(50))
        #expect(await remote.subjectCallCount == 0)
    }

    @Test func anISBNLookupIsCachedAsASingleResult() async throws {
        let remote = BookSearchingMock(result: [makeReference(id: "isbn-1")])
        let store = BookCacheStoreMock()

        let searching = CachedBookSearching(remote: remote, store: store)
        let first = try await searching.findBook(isbn: "9780140449136")
        let second = try await searching.findBook(isbn: "9780140449136")

        #expect(first.id == "isbn-1")
        #expect(second.id == "isbn-1")
        #expect(await remote.isbnCallCount == 1)
    }

    private func confirmEventually(
        within duration: Duration = .seconds(2),
        _ condition: @Sendable () async -> Bool
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: duration)
        while ContinuousClock.now < deadline {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Condition was not met within \(duration)")
    }
}

@Suite struct BookQueryTests {

    @Test func eachKindOfQueryGetsItsOwnKey() {
        #expect(BookQuery.search(text: "Dune", maxResults: 20).cacheKey == "search:dune:20")
        #expect(BookQuery.subject("History", maxResults: 15).cacheKey == "subject:history:15")
        #expect(BookQuery.isbn(" 9780140449136 ").cacheKey == "isbn:9780140449136")
    }

    @Test func resultCountIsPartOfTheKeySoAWiderRequestIsNotAnsweredWithAShortList() {
        #expect(BookQuery.search(text: "dune", maxResults: 20).cacheKey
                != BookQuery.search(text: "dune", maxResults: 40).cacheKey)
    }

    /// SWR'ın çalışma koşulu: tazeleme penceresi, satırın ömründen kısa olmalı.
    @Test func everyQueryIsRefreshedBeforeItExpires() {
        let queries: [BookQuery] = [
            .search(text: "dune", maxResults: 20),
            .subject("history", maxResults: 15),
            .isbn("9780140449136")
        ]
        for query in queries {
            #expect(query.refreshInterval < query.timeToLive)
        }
    }
}

@Suite struct BookReferenceMergingTests {

    @Test func aRicherRecordFillsTheGapsOfAPoorerOne() {
        let list = BookReference(id: "1", title: "Dune", authors: ["Herbert"], pageCount: 412)
        let detail = BookReference(id: "1", title: "Dune", description: "A desert planet.", subjects: ["Fiction"])

        let merged = list.merging(detail)

        #expect(merged.pageCount == 412)
        #expect(merged.description == "A desert planet.")
        #expect(merged.subjects == ["Fiction"])
        #expect(merged.authors == ["Herbert"])
    }

    @Test func anEmptyValueNeverOverwritesAKnownOne() {
        let known = BookReference(id: "1", title: "Dune", authors: ["Herbert"],
                                  coverURL: URL(string: "https://example.com/1.jpg"), pageCount: 412)
        let empty = BookReference(id: "1", title: "")

        let merged = known.merging(empty)

        #expect(merged.title == "Dune")
        #expect(merged.authors == ["Herbert"])
        #expect(merged.coverURL != nil)
        #expect(merged.pageCount == 412)
    }

    @Test func theLongerDescriptionWins() {
        let short = BookReference(id: "1", title: "Dune", description: "Short.")
        let long = BookReference(id: "1", title: "Dune", description: "A considerably longer summary.")

        #expect(short.merging(long).description == "A considerably longer summary.")
        #expect(long.merging(short).description == "A considerably longer summary.")
    }
}

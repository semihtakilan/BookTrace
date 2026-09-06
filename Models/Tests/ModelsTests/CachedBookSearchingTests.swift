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

    @Test func aStoredDescriptionIsAvailableWithoutAnotherDetailRequest() async throws {
        let remote = BookSearchingMock()
        let store = BookCacheStoreMock()
        await store.merge(BookReference(id: "book", title: "Dune", description: "A desert planet."))
        let searching = CachedBookSearching(remote: remote, store: store)

        let detail = try await searching.detail(for: makeReference(id: "book", pageCount: 412))

        #expect(detail.description == "A desert planet.")
        #expect(detail.pageCount == 412)
        #expect(await remote.detailCallCount == 0)
    }

    @Test func concurrentDetailsShareOneRequestAcrossDecoratorCopies() async throws {
        let remote = ControlledCachedDetailFetching()
        let store = BookCacheStoreMock()
        let clock = DetailCacheTestClock()
        let searching = CachedBookSearching(
            remote: remote, store: store, missingDetailRetryInterval: 30, now: clock.now
        )
        let copy = searching
        let first = Task { try await searching.detail(for: makeReference(id: "book", pageCount: 412)) }
        let second = Task { try await copy.detail(for: makeReference(id: "book")) }
        try await confirmEventually {
            let calls = await remote.callCount
            return clock.readCount == 2 && calls == 1
        }

        await remote.complete(with: BookReference(id: "another-source-id", title: "Dune", description: "A desert planet."))
        let results = try await [first.value, second.value]

        #expect(results.allSatisfy { $0.id == "book" && $0.description == "A desert planet." })
        #expect(results[0].pageCount == 412)
        #expect(await remote.callCount == 1)
        #expect(await store.book(id: "book")?.description == "A desert planet.")
    }

    @Test func missingDescriptionsRetryAfterABriefCooldown() async throws {
        let remote = BookSearchingMock(detailDescription: " \n ")
        let clock = DetailCacheTestClock()
        let searching = CachedBookSearching(
            remote: remote, store: BookCacheStoreMock(), missingDetailRetryInterval: 30, now: clock.now
        )
        let book = makeReference(id: "book")

        _ = try await searching.detail(for: book)
        _ = try await searching.detail(for: book)
        #expect(await remote.detailCallCount == 1)

        clock.advance(by: 31)
        _ = try await searching.detail(for: book)
        #expect(await remote.detailCallCount == 2)
    }

    @Test func freshMetadataWithADescriptionBypassesTheMissingDescriptionCooldown() async throws {
        let remote = BookSearchingMock()
        let store = BookCacheStoreMock()
        let searching = CachedBookSearching(remote: remote, store: store)
        _ = try await searching.detail(for: makeReference(id: "book"))
        await store.merge(BookReference(id: "book", title: "Dune", description: "A desert planet."))

        let detail = try await searching.detail(for: makeReference(id: "book"))

        #expect(detail.description == "A desert planet.")
        #expect(await remote.detailCallCount == 1)
    }

    @Test func cancellingOneWaiterKeepsTheSharedRequestAlive() async throws {
        let remote = ControlledCachedDetailFetching()
        let clock = DetailCacheTestClock()
        let searching = CachedBookSearching(
            remote: remote, store: BookCacheStoreMock(), missingDetailRetryInterval: 30, now: clock.now
        )
        let first = Task { try await searching.detail(for: makeReference(id: "book")) }
        let second = Task { try await searching.detail(for: makeReference(id: "book")) }
        try await confirmEventually {
            let calls = await remote.callCount
            return clock.readCount == 2 && calls == 1
        }

        first.cancel()
        await #expect(throws: CancellationError.self) { try await first.value }
        #expect(await remote.cancellationCount == 0)

        await remote.complete(with: BookReference(id: "book", title: "Dune", description: "A desert planet."))
        #expect(try await second.value.description == "A desert planet.")
        #expect(await remote.callCount == 1)
    }

    @Test func cancellingTheLastWaiterCancelsTheRequestAndAllowsAnImmediateRetry() async throws {
        let remote = ControlledCachedDetailFetching()
        let store = BookCacheStoreMock()
        let searching = CachedBookSearching(remote: remote, store: store)
        let first = Task { try await searching.detail(for: makeReference(id: "book")) }
        try await confirmEventually { await remote.callCount == 1 }

        first.cancel()
        await #expect(throws: CancellationError.self) { try await first.value }
        try await confirmEventually { await remote.cancellationCount == 1 }
        #expect(await store.book(id: "book") == nil)

        let retry = Task { try await searching.detail(for: makeReference(id: "book")) }
        try await confirmEventually { await remote.callCount == 2 }
        await remote.complete(with: BookReference(id: "book", title: "Dune", description: "A desert planet."))
        #expect(try await retry.value.description == "A desert planet.")
    }

    @Test func failedDetailsAreRetriedWithoutNegativeCaching() async throws {
        let remote = ControlledCachedDetailFetching()
        let searching = CachedBookSearching(remote: remote, store: BookCacheStoreMock())
        let first = Task { try await searching.detail(for: makeReference(id: "book")) }
        try await confirmEventually { await remote.callCount == 1 }
        await remote.fail()
        await #expect(throws: URLError.self) { try await first.value }

        let retry = Task { try await searching.detail(for: makeReference(id: "book")) }
        try await confirmEventually { await remote.callCount == 2 }
        await remote.complete(with: makeReference(id: "book"))
        #expect(try await retry.value.id == "book")
    }

    @Test func missingDescriptionMemoryIsBounded() async throws {
        let remote = BookSearchingMock()
        let clock = DetailCacheTestClock()
        let searching = CachedBookSearching(
            remote: remote, store: BookCacheStoreMock(), missingDetailRetryInterval: 300, now: clock.now
        )
        for index in 0...128 {
            _ = try await searching.detail(for: makeReference(id: "book-\(index)"))
            clock.advance(by: 1)
        }

        _ = try await searching.detail(for: makeReference(id: "book-128"))
        #expect(await remote.detailCallCount == 129)
        _ = try await searching.detail(for: makeReference(id: "book-0"))
        #expect(await remote.detailCallCount == 130)
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

private final class DetailCacheTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date(timeIntervalSince1970: 1_000)
    private var reads = 0

    var readCount: Int { lock.withLock { reads } }

    func now() -> Date {
        lock.withLock {
            reads += 1
            return date
        }
    }

    func advance(by interval: TimeInterval) {
        lock.withLock { date.addTimeInterval(interval) }
    }
}

private actor ControlledCachedDetailFetching: BookSearching, BookDetailFetching {
    private var continuations: [UUID: CheckedContinuation<BookReference, any Error>] = [:]
    private(set) var callCount = 0
    private(set) var cancellationCount = 0

    func searchBooks(query: String, maxResults: Int) async throws -> [BookReference] { [] }
    func books(inSubject subject: String, maxResults: Int) async throws -> [BookReference] { [] }
    func findBook(isbn: String) async throws -> BookReference { makeReference(id: isbn) }

    func detail(for book: BookReference) async throws -> BookReference {
        try Task.checkCancellation()
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                callCount += 1
                continuations[id] = continuation
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }

    func complete(with book: BookReference) {
        let pending = continuations.values
        continuations.removeAll()
        for continuation in pending { continuation.resume(returning: book) }
    }

    func fail() {
        let pending = continuations.values
        continuations.removeAll()
        for continuation in pending { continuation.resume(throwing: URLError(.timedOut)) }
    }

    private func cancel(_ id: UUID) {
        guard let continuation = continuations.removeValue(forKey: id) else { return }
        cancellationCount += 1
        continuation.resume(throwing: CancellationError())
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

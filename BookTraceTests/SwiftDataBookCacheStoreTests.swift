//
//  SwiftDataBookCacheStoreTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation
import Models
import SwiftData
import Testing
@testable import BookTrace

/// Aynı süreçte birden çok `ModelContainer` yan yana yaşayamadığı için sıralı.
@Suite(.serialized)
struct SwiftDataBookCacheStoreTests {

    private func makeStore() throws -> SwiftDataBookCacheStore {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: BookCacheStorage.schema, configurations: configuration)
        return SwiftDataBookCacheStore(modelContainer: container)
    }

    @Test func aStoredQueryComesBackInTheOrderItWasWritten() async throws {
        let store = try makeStore()
        let query = BookQuery.subject("history", maxResults: 15)
        let books = ["c", "a", "b"].map { BookReference(id: $0, title: $0.uppercased()) }

        await store.store(books, for: query)
        let cached = await store.books(for: query)

        #expect(cached?.books.map(\.id) == ["c", "a", "b"])
        #expect(cached?.isStale == false)
    }

    @Test func anUnknownQueryIsAMiss() async throws {
        let store = try makeStore()
        #expect(await store.books(for: .search(text: "nothing", maxResults: 20)) == nil)
    }

    /// İki raf aynı kitabı içerdiğinde disk üzerinde tek satır olmalı — hibrit
    /// kurgunun tasarrufu buradan geliyor.
    @Test func aBookAppearingInTwoQueriesIsStoredOnce() async throws {
        let store = try makeStore()
        let shared = BookReference(id: "shared", title: "Dune")

        await store.store([shared, BookReference(id: "a", title: "A")], for: .subject("fiction", maxResults: 15))
        await store.store([shared, BookReference(id: "b", title: "B")], for: .subject("history", maxResults: 15))

        #expect(await store.bookCount() == 3)
    }

    @Test func aLaterDetailEnrichesTheRowInsteadOfReplacingIt() async throws {
        let store = try makeStore()
        let listResult = BookReference(id: "1", title: "Dune", authors: ["Herbert"], pageCount: 412)
        await store.store([listResult], for: .search(text: "dune", maxResults: 20))

        await store.merge(BookReference(id: "1", title: "Dune", description: "A desert planet."))

        let book = try #require(await store.book(id: "1"))
        #expect(book.pageCount == 412)
        #expect(book.authors == ["Herbert"])
        #expect(book.description == "A desert planet.")
    }

    /// Zenginleşen satır listeye de yansımalı: kullanıcı detayı açıp geri
    /// döndüğünde raf, elindeki en iyi veriyi göstermeli.
    @Test func enrichmentIsVisibleThroughTheQueryThatHoldsTheBook() async throws {
        let store = try makeStore()
        let query = BookQuery.search(text: "dune", maxResults: 20)
        await store.store([BookReference(id: "1", title: "Dune")], for: query)

        await store.merge(BookReference(id: "1", title: "Dune", pageCount: 412))

        let cached = await store.books(for: query)
        #expect(cached?.books.first?.pageCount == 412)
    }

    @Test func rewritingAQueryReplacesItsResultsRatherThanAppending() async throws {
        let store = try makeStore()
        let query = BookQuery.search(text: "dune", maxResults: 20)

        await store.store([BookReference(id: "1", title: "One")], for: query)
        await store.store([BookReference(id: "2", title: "Two")], for: query)

        #expect(await store.books(for: query)?.books.map(\.id) == ["2"])
    }

    @Test func clearingRemovesEverything() async throws {
        let store = try makeStore()
        await store.store([BookReference(id: "1", title: "One")], for: .search(text: "one", maxResults: 20))

        await store.removeAll()

        #expect(await store.books(for: .search(text: "one", maxResults: 20)) == nil)
        #expect(await store.bookCount() == 0)
    }

    @Test func anExpiredQueryIsDroppedAndReportedAsAMiss() async throws {
        let store = try makeStore()
        let query = BookQuery.isbn("9780140449136")

        await store.store(
            [BookReference(id: "1", title: "Crime and Punishment")],
            for: query,
            writtenAt: Date(timeIntervalSinceNow: -query.timeToLive - 1)
        )

        #expect(await store.books(for: query) == nil)
    }

    /// Tazeleme penceresini geçmiş ama ömrü dolmamış satır: veri gelmeli,
    /// üzerinde "bayat" bayrağıyla.
    @Test func aQueryPastItsRefreshWindowIsServedButMarkedStale() async throws {
        let store = try makeStore()
        let query = BookQuery.subject("history", maxResults: 15)

        await store.store(
            [BookReference(id: "1", title: "A History")],
            for: query,
            writtenAt: Date(timeIntervalSinceNow: -query.refreshInterval - 1)
        )

        let cached = await store.books(for: query)
        #expect(cached?.books.map(\.id) == ["1"])
        #expect(cached?.isStale == true)
    }

    /// Kitap budandığında ona işaret eden sorgu eksik liste döndürmemeli.
    @Test func aQueryWhoseBooksWerePrunedIsTreatedAsAMiss() async throws {
        let store = try makeStore()
        let query = BookQuery.subject("fiction", maxResults: 15)
        await store.store(
            [BookReference(id: "1", title: "One"), BookReference(id: "2", title: "Two")],
            for: query
        )

        await store.removeBook(id: "2")

        #expect(await store.books(for: query) == nil)
    }
}

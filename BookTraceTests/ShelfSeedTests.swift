//
//  ShelfSeedTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 04.09.2026.
//

import Foundation
import Models
import SwiftData
import Testing
@testable import BookTrace

/// Tohum dosyası `Scripts/generate_shelf_seed.py` ile üretiliyor; eşleme
/// mantığı `OpenLibraryDocument.toDomain()` ile elle hizalı tutuluyor. Bu suite
/// o hizanın bozulduğunu yakalayan yer.
@Suite struct ShelfSeedTests {

    @Test func everyFeaturedShelfIsInTheBundledSeed() {
        let seed = ShelfSeed()

        for subject in BookSubject.featured {
            let books = seed.books(for: .subject(subject.query, maxResults: 15))
            #expect(books?.count == 15, "\(subject.query) rafı tohumda eksik")
        }
    }

    /// Rafın işi göze hitap etmek; kapaksız kart sırayı boşaltıyor.
    @Test func seededBooksCarryTheDataTheShelfNeedsToDraw() throws {
        let seed = ShelfSeed()
        let books = try #require(seed.books(for: .subject("fiction", maxResults: 15)))

        for book in books {
            #expect(!book.title.isEmpty)
            #expect(!book.authors.isEmpty)
            #expect(book.coverURL != nil)
            // Kimlik önekli olmalı, yoksa aynı kitap ağdan gelince ikinci kez kaydedilir.
            #expect(book.source == .openLibrary)
        }
    }

    @Test func theSeedOnlyAnswersShelfQueries() {
        let seed = ShelfSeed()

        #expect(seed.books(for: .search(text: "fiction", maxResults: 20)) == nil)
        #expect(seed.books(for: .isbn("9780140449136")) == nil)
        #expect(seed.books(for: .subject("gardening", maxResults: 15)) == nil)
    }

    @Test func aMissingSeedFileLeavesTheAppWorkingWithoutOne() {
        let seed = ShelfSeed(bundle: .main, resource: "NoSuchSeed")
        #expect(seed.books(for: .subject("fiction", maxResults: 15)) == nil)
    }
}

@Suite(.serialized)
struct SeededCacheStoreTests {

    private struct StubSeed: BookSeedProviding {
        let books: [BookReference]

        func books(for query: BookQuery) -> [BookReference]? {
            guard case .subject = query else { return nil }
            return books
        }
    }

    private func makeStore(seed: any BookSeedProviding) async throws -> SwiftDataBookCacheStore {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: BookCacheStorage.schema, configurations: configuration)
        let store = SwiftDataBookCacheStore(modelContainer: container)
        await store.use(seed: seed)
        return store
    }

    /// Boş cache'te raf sorusu tohumdan cevaplanmalı — ve **bayat** olarak,
    /// yoksa gömülü anlık görüntü günlerce tazelenmeden kalır.
    @Test func anEmptyCacheAnswersAShelfFromTheSeedAndMarksItStale() async throws {
        let store = try await makeStore(seed: StubSeed(books: [BookReference(id: "ol:/works/1", title: "Seeded")]))

        let cached = await store.books(for: .subject("fiction", maxResults: 15))

        #expect(cached?.books.map(\.id) == ["ol:/works/1"])
        #expect(cached?.isStale == true)
    }

    /// Tohum yalnızca boşluğu dolduruyor; gerçek veri geldikten sonra susuyor.
    @Test func realDataTakesPrecedenceOverTheSeed() async throws {
        let store = try await makeStore(seed: StubSeed(books: [BookReference(id: "ol:/works/seed", title: "Seeded")]))
        let query = BookQuery.subject("fiction", maxResults: 15)

        await store.store([BookReference(id: "ol:/works/live", title: "Live")], for: query)
        let cached = await store.books(for: query)

        #expect(cached?.books.map(\.id) == ["ol:/works/live"])
        #expect(cached?.isStale == false)
    }

    @Test func aSearchIsNeverAnsweredFromTheShelfSeed() async throws {
        let store = try await makeStore(seed: StubSeed(books: [BookReference(id: "ol:/works/1", title: "Seeded")]))

        #expect(await store.books(for: .search(text: "dune", maxResults: 20)) == nil)
    }
}

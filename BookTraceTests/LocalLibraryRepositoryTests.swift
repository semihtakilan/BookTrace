//
//  LocalLibraryRepositoryTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation
import Models
import Testing
@testable import BookTrace

/// SwiftData, tek süreçte aynı anda birden fazla `ModelContainer` kurulmasını
/// kaldıramıyor; bu paket sıralı çalışır.
@MainActor
@Suite(.serialized)
struct LocalLibraryRepositoryTests {

    @Test func aLegacyFinishedRecordWithZeroPagesLoadsAsComplete() {
        let record = LocalLibraryEntryModel(entry: makeEntry(pageCount: 240), categories: [])
        record.readingStatusRawValue = ReadingStatus.finished.rawValue
        record.currentPage = 0
        let entry = record.toDomain()
        #expect(entry.readingStatus == .finished)
        #expect(entry.currentPage == 240)
        #expect(entry.progressPercentage == 100)
        #expect(entry.readingSessions.isEmpty)
    }

    @Test func addingTheSameBookTwiceUpdatesTheExistingRecord() throws {
        let (repository, _) = try makeInMemoryRepository()

        try repository.add(makeEntry(readingStatus: .toRead, currentPage: 0))
        try repository.add(makeEntry(readingStatus: .reading, ownershipStatus: .owned, currentPage: 40))

        let entries = try repository.fetchEntries()
        #expect(entries.count == 1)
        #expect(entries[0].readingStatus == .reading)
        #expect(entries[0].ownershipStatus == .owned)
        #expect(entries[0].currentPage == 40)
    }

    @Test func aTagSharedByTwoBooksBecomesASingleCategory() throws {
        let (repository, _) = try makeInMemoryRepository()
        let favorites = Models.Category(name: "Favorites")

        try repository.add(makeEntry(id: "a", title: "Dune", categories: [favorites]))
        // Aynı ad, farklı yazım — kimlik normalize edildiği için aynı kayda bağlanmalı.
        try repository.add(makeEntry(id: "b", title: "Neuromancer", categories: [Models.Category(name: "favorites")]))

        let categories = try repository.fetchCategories()
        #expect(categories.count == 1)
        #expect(categories[0].id == favorites.id)

        let entries = try repository.fetchEntries()
        #expect(entries.allSatisfy { $0.categories.count == 1 })
    }

    @Test func fetchingCategoriesDoesNotDependOnTheEntries() throws {
        let (repository, _) = try makeInMemoryRepository()

        #expect(try repository.fetchCategories().isEmpty)

        try repository.add(makeEntry(categories: [Models.Category(name: "Work"), Models.Category(name: "Reread")]))

        #expect(try repository.fetchCategories().map(\.name).sorted() == ["Reread", "Work"])
    }

    @Test func aSessionAdvancesProgressAndIsStoredWithTheBook() throws {
        let (repository, _) = try makeInMemoryRepository()
        try repository.add(makeEntry(pageCount: 300, currentPage: 0))

        let updated = try repository.appendSession(
            ReadingSession(startDate: Date(), durationSeconds: 1_800, pagesRead: 30),
            toEntryWith: "book-1"
        )

        #expect(updated.currentPage == 30)
        #expect(updated.readingStatus == .reading)
        #expect(updated.readingSessions.count == 1)
        #expect(try repository.entry(for: "book-1")?.totalReadSeconds == 1_800)
    }

    @Test func deletingABookAlsoRemovesItsSessions() throws {
        let (repository, _) = try makeInMemoryRepository()
        try repository.add(makeEntry(pageCount: 300))
        try repository.appendSession(
            ReadingSession(startDate: Date(), durationSeconds: 600, pagesRead: 10),
            toEntryWith: "book-1"
        )

        try repository.delete(id: "book-1")

        #expect(try repository.fetchEntries().isEmpty)
        #expect(try repository.entry(for: "book-1") == nil)
    }

    @Test func actingOnAMissingBookReportsItRatherThanFailingSilently() throws {
        let (repository, _) = try makeInMemoryRepository()

        #expect(throws: LocalLibraryRepositoryError.self) {
            try repository.delete(id: "nope")
        }
        #expect(throws: LocalLibraryRepositoryError.self) {
            try repository.update(makeEntry(id: "nope"))
        }
        #expect(throws: LocalLibraryRepositoryError.self) {
            try repository.appendSession(
                ReadingSession(startDate: Date(), durationSeconds: 60, pagesRead: 1),
                toEntryWith: "nope"
            )
        }
    }

    @Test func everyWriteBumpsTheChangeCounterSoOpenScreensRefresh() throws {
        let (repository, notifier) = try makeInMemoryRepository()
        #expect(notifier.revision == 0)

        try repository.add(makeEntry())
        #expect(notifier.revision == 1)

        try repository.appendSession(
            ReadingSession(startDate: Date(), durationSeconds: 60, pagesRead: 1),
            toEntryWith: "book-1"
        )
        #expect(notifier.revision == 2)

        try repository.delete(id: "book-1")
        #expect(notifier.revision == 3)
    }

    @Test func deletingABookRemovesTagsNothingElseUses() throws {
        let (repository, _) = try makeInMemoryRepository()
        try repository.add(makeEntry(id: "a", categories: [
            Models.Category(name: "Work"),
            Models.Category(name: "Shared"),
        ]))
        try repository.add(makeEntry(id: "b", categories: [Models.Category(name: "Shared")]))

        try repository.delete(id: "a")

        // İlişki `.nullify` olduğu için etiketler kitapla birlikte silinmiyordu;
        // "Shared" hâlâ b'ye bağlı, "Work" ise sahipsiz kaldı.
        #expect(try repository.fetchCategories().map(\.name) == ["Shared"])
    }

    @Test func aTagStopsBeingRenamedByASecondBook() throws {
        let (repository, _) = try makeInMemoryRepository()
        try repository.add(makeEntry(id: "a", categories: [Models.Category(name: "Deep Work")]))

        // Aynı kimlik, farklı yazım: ilk kitaptaki adı değiştirmemeli.
        try repository.add(makeEntry(id: "b", categories: [Models.Category(name: "deep-work")]))

        #expect(try repository.fetchCategories().map(\.name) == ["Deep Work"])
    }

    @Test func erasingTheLibraryClearsBooksAndTags() throws {
        let (repository, _) = try makeInMemoryRepository()
        try repository.add(makeEntry(id: "a", categories: [Models.Category(name: "Work")]))
        try repository.add(makeEntry(id: "b", categories: [Models.Category(name: "Gift")]))

        try repository.deleteAll()

        #expect(try repository.fetchEntries().isEmpty)
        #expect(try repository.fetchCategories().isEmpty)
    }

    @Test func theRemoteSnapshotIsStoredSoTheLibraryWorksOffline() throws {
        let (repository, _) = try makeInMemoryRepository()
        let book = BookReference(
            id: "book-1",
            title: "Dune",
            authors: ["Frank Herbert"],
            coverURL: URL(string: "https://example.com/cover.jpg"),
            pageCount: 412,
            publishedDate: "1965",
            description: "Desert planet",
            isbn13: "9780441013593",
            subjects: ["Fiction"]
        )
        try repository.add(LibraryEntry(book: book))

        let stored = try #require(try repository.entry(for: "book-1")).book
        #expect(stored.title == "Dune")
        #expect(stored.coverURL?.absoluteString == "https://example.com/cover.jpg")
        #expect(stored.pageCount == 412)
        #expect(stored.isbn13 == "9780441013593")
        #expect(stored.subjects == ["Fiction"])
    }
}

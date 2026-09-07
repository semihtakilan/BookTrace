//
//  LocalLibraryRepositoryTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import BookTraceShared
import Foundation
import Models
import SwiftData
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

    @Test func persistedSessionsUseTheRemainingPagesSoStatisticsMatchProgress() throws {
        let (repository, _) = try makeInMemoryRepository()
        try repository.add(makeEntry(readingStatus: .reading, pageCount: 300, currentPage: 290))
        let session = ReadingSession(startDate: Date(), durationSeconds: 600, pagesRead: 80)

        let updated = try repository.appendSession(session, toEntryWith: "book-1")
        let reloaded = try #require(try repository.entry(for: "book-1"))

        #expect(updated.currentPage == 300)
        #expect(reloaded.readingStatus == .finished)
        #expect(reloaded.readingSessions.first?.id == session.id)
        #expect(reloaded.totalPagesRead == 10)
        #expect(reloaded.totalReadSeconds == 600)
        #expect(reloaded.secondsPerPage == 60)
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

    @Test func erasingTheLibraryAlsoRemovesUnattachedImportedSessionsAndQuotes() throws {
        let (repository, context) = try makeRepositoryAndContext()
        context.insert(LocalReadingSessionModel(session: ReadingSession(startDate: Date(), durationSeconds: 600, pagesRead: 10)))
        context.insert(BookTraceShared.LocalQuoteModel(quote: Quote(text: "Orphan quote")))
        context.insert(BookTraceShared.LocalReadingGoalModel(goal: ReadingGoal(period: .yearly, metric: .books, target: 12)))
        try context.save()

        try repository.deleteAll()

        #expect(try context.fetchCount(FetchDescriptor<LocalReadingSessionModel>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<BookTraceShared.LocalQuoteModel>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<BookTraceShared.LocalReadingGoalModel>()) == 0)
    }

    @Test func deletingABookRemovesEveryPendingCloudDuplicateAndItsChildren() throws {
        let (repository, context) = try makeRepositoryAndContext()
        for suffix in ["a", "b"] {
            var entry = makeEntry(id: "duplicate", sessions: [ReadingSession(id: suffix, startDate: Date(), durationSeconds: 600, pagesRead: 10)])
            entry.quotes = [Quote(id: suffix, text: "Quote")]
            context.insert(LocalLibraryEntryModel(entry: entry))
        }
        try context.save()

        try repository.delete(id: "duplicate")

        #expect(try repository.fetchEntries().isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<LocalReadingSessionModel>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<BookTraceShared.LocalQuoteModel>()) == 0)
    }

    @Test func editingOrDeletingABookDoesNotPruneAnUnrelatedIncomingCategory() throws {
        let (repository, context) = try makeRepositoryAndContext()
        let incoming = LocalCategoryModel(category: Models.Category(name: "Incoming cloud category"))
        context.insert(incoming)
        try context.save()
        let detached = Models.Category(name: "Locally removed")
        try repository.add(makeEntry(id: "a", categories: [detached]))
        var edited = try #require(try repository.entry(for: "a"))
        edited.categories = []
        try repository.update(edited)

        #expect(try repository.fetchCategories().map(\.name) == ["Incoming cloud category"])

        try repository.delete(id: "a")
        #expect(try repository.fetchCategories().map(\.name) == ["Incoming cloud category"])
    }

    @Test func appendingTheSameSessionIDTwiceDoesNotAdvanceProgressOrNotifyTwice() throws {
        let (repository, notifier) = try makeInMemoryRepository()
        try repository.add(makeEntry(pageCount: 100))
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let session = ReadingSession(id: "replayed", startDate: date, durationSeconds: 60, pagesRead: 5)
        try repository.appendSession(session, toEntryWith: "book-1")
        let revision = notifier.revision

        let replay = ReadingSession(id: session.id, startDate: date, durationSeconds: 120, pagesRead: 10)
        let result = try repository.appendSession(replay, toEntryWith: "book-1")

        #expect(result.currentPage == 5)
        #expect(result.readingSessions == [session])
        #expect(result.totalReadSeconds == 60)
        #expect(notifier.revision == revision)
    }

    @Test(arguments: RepositoryFailingMutation.allCases)
    func aFailedMutationRollsBackBeforeAnyLaterSuccessfulWrite(_ operation: RepositoryFailingMutation) throws {
        _ = try makeInMemoryRepository()
        let context = TestStore.container.mainContext
        let notifier = LibraryChangeNotifier()
        var shouldFailSave = false
        let repository = LocalLibraryRepositoryImpl(modelContext: context, changeNotifier: notifier, saveChanges: { context in
            if shouldFailSave { throw RepositoryInjectedSaveError.failed }
            try context.save()
        })
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        var entry = makeEntry(pageCount: 200, currentPage: 20, categories: [Models.Category(name: "Original")],
                              sessions: [ReadingSession(id: "original", startDate: date, durationSeconds: 600, pagesRead: 20)])
        entry.quotes = [Quote(id: "original", text: "Keep this quote", createdDate: date)]
        try repository.add(entry)
        let baseline = try #require(try repository.entry(for: entry.id))
        let revision = notifier.revision
        shouldFailSave = true

        #expect(throws: RepositoryInjectedSaveError.self) {
            switch operation {
            case .add:
                try repository.add(makeEntry(id: "failed-add", categories: [Models.Category(name: "Transient")]))
            case .upsert, .update:
                var changed = baseline
                changed.currentPage = 50
                changed.categories = [Models.Category(name: "Transient")]
                changed.quotes = []
                if operation == .upsert { try repository.add(changed) }
                else { try repository.update(changed) }
            case .append:
                try repository.appendSession(ReadingSession(id: "failed-session", startDate: date, durationSeconds: 300, pagesRead: 10), toEntryWith: entry.id)
            case .delete:
                try repository.delete(id: entry.id)
            case .deleteAll:
                try repository.deleteAll()
            }
        }

        #expect(!context.hasChanges)
        #expect(try repository.fetchEntries() == [baseline])
        #expect(try repository.fetchCategories().map(\.name) == ["Original"])
        #expect(notifier.revision == revision)

        shouldFailSave = false
        try repository.add(makeEntry(id: "later-success"))
        #expect(try repository.entry(for: baseline.id) == baseline)
        #expect(try repository.entry(for: "failed-add") == nil)
        #expect(try context.fetchCount(FetchDescriptor<LocalReadingSessionModel>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<BookTraceShared.LocalQuoteModel>()) == 1)
    }

    private func makeRepositoryAndContext() throws -> (LocalLibraryRepositoryImpl, ModelContext) {
        let (repository, _) = try makeInMemoryRepository()
        return (repository, TestStore.container.mainContext)
    }
}

nonisolated enum RepositoryFailingMutation: CaseIterable, Sendable {
    case add, upsert, update, append, delete, deleteAll
}

nonisolated enum RepositoryInjectedSaveError: Error { case failed }

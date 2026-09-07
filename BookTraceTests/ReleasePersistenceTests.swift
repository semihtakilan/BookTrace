//
//  ReleasePersistenceTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import BookTraceShared
import Foundation
import Models
import SwiftData
import Testing
@testable import BookTrace

@MainActor
@Suite(.serialized)
struct ReleasePersistenceTests {
    @Test func v1StoreMigratesWithoutLosingSessionsCategoriesOrCompletionDate() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("migration.store")
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        try autoreleasepool {
            let schema = Schema(versionedSchema: LibrarySchemaV1.self)
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
            let session = ReadingSession(id: "session", startDate: date, durationSeconds: 600, pagesRead: 20)
            let entry = LibraryEntry(book: BookReference(id: "gb:legacy", title: "Legacy", pageCount: 100), readingStatus: .finished,
                                     categories: [Models.Category(name: "Classic")], readingSessions: [session])
            let category = LibrarySchemaV1.LocalCategoryModel(category: entry.categories[0])
            container.mainContext.insert(LibrarySchemaV1.LocalLibraryEntryModel(entry: entry, categories: [category]))
            container.mainContext.insert(LibrarySchemaV1.LocalLibraryEntryModel(entry: LibraryEntry(book: BookReference(id: "gb:undated", title: "Undated"), readingStatus: .finished), categories: []))
            try container.mainContext.save()
        }
        let migrated = try ModelContainer(for: LocalStore.schema, migrationPlan: LibraryMigrationPlan.self,
            configurations: ModelConfiguration(schema: LocalStore.schema, url: url, cloudKitDatabase: .none))
        defer { withExtendedLifetime(migrated) {} }
        let migratedRows = try migrated.mainContext.fetch(FetchDescriptor<BookTraceShared.LocalLibraryEntryModel>())
        let entries = migratedRows.map { $0.toDomain() }
        let rowIDs = migratedRows.map(\.rowID)
            + (try migrated.mainContext.fetch(FetchDescriptor<BookTraceShared.LocalReadingSessionModel>())).map(\.rowID)
            + (try migrated.mainContext.fetch(FetchDescriptor<BookTraceShared.LocalCategoryModel>())).map(\.rowID)
        #expect(rowIDs.count == 4)
        #expect(rowIDs.allSatisfy { UUID(uuidString: $0) != nil })
        #expect(Set(rowIDs).count == rowIDs.count)
        let legacy = try #require(entries.first { $0.id == "gb:legacy" })
        #expect(legacy.readingSessions.map(\.id) == ["session"])
        #expect(legacy.categories.first?.name == "Classic")
        #expect(legacy.currentPage == 100)
        #expect(legacy.finishedDate == date)
        #expect(entries.first { $0.id == "gb:undated" }?.finishedDate == nil)
    }

    @Test func duplicateCloudImportsKeepChildrenAndDoNotDoubleCountTime() throws {
        let configuration = ModelConfiguration(schema: LocalStore.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: LocalStore.schema, configurations: configuration)
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let session = ReadingSession(id: "same-session", startDate: date, durationSeconds: 600, pagesRead: 20)
        var first = LibraryEntry(book: BookReference(id: "gb:book", title: "Book", pageCount: 200), readingStatus: .reading,
                                 currentPage: 20, addedDate: date, readingSessions: [session], notes: "First note")
        first.quotes = [Quote(id: "q1", text: "First quote")]
        var second = first
        second.currentPage = 100
        second.addedDate = date.addingTimeInterval(100)
        second.isFavorite = true
        second.notes = "Second note"
        second.readingSessions.append(ReadingSession(id: "new-session", startDate: date, durationSeconds: 300, pagesRead: 10))
        second.quotes = [Quote(id: "q2", text: "Second quote")]
        context.insert(BookTraceShared.LocalLibraryEntryModel(entry: first))
        context.insert(BookTraceShared.LocalLibraryEntryModel(entry: second))
        try context.save()
        #expect(try LibraryDeduplicator.run(in: context))
        let entries = try context.fetch(FetchDescriptor<BookTraceShared.LocalLibraryEntryModel>())
        #expect(entries.count == 1)
        let merged = try #require(entries.first).toDomain()
        #expect(merged.addedDate == date)
        #expect(merged.currentPage == 100)
        #expect(merged.isFavorite)
        #expect(merged.totalReadSeconds == 900)
        #expect(Set(merged.quotes.map(\.id)) == ["q1", "q2"])
        #expect(merged.notes?.contains("First note") == true)
        #expect(merged.notes?.contains("Second note") == true)
        #expect(try !LibraryDeduplicator.run(in: context))
    }

    @Test func groupCopyRetainsOriginalStoreAndEveryJournal() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("legacy/default.store")
        let group = root.appendingPathComponent("group")
        try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: group, withIntermediateDirectories: true)
        for suffix in ["", "-wal", "-shm"] { try Data(("payload" + suffix).utf8).write(to: URL(fileURLWithPath: source.path + suffix)) }
        let destination = try LocalStore.prepareLocation(legacy: source, group: group)
        for suffix in ["", "-wal", "-shm"] {
            #expect(try Data(contentsOf: URL(fileURLWithPath: source.path + suffix)) == Data(contentsOf: URL(fileURLWithPath: destination.path + suffix)))
        }
        #expect(try LocalStore.prepareLocation(legacy: source, group: group) == destination)
        #expect(try LocalStore.prepareLocation(legacy: source, group: nil) == source)
        let invalidGroup = root.appendingPathComponent("file-not-directory")
        try Data().write(to: invalidGroup)
        #expect(throws: (any Error).self) { try LocalStore.prepareLocation(legacy: source, group: invalidGroup) }
        #expect(FileManager.default.fileExists(atPath: source.path))
    }

    @Test func resetRemovesRetainedMigrationCopyAndCannotRestoreDeletedData() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("legacy/default.store")
        let group = root.appendingPathComponent("group")
        try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: group, withIntermediateDirectories: true)
        for suffix in ["", "-wal", "-shm"] { try Data("legacy".utf8).write(to: URL(fileURLWithPath: source.path + suffix)) }
        let destination = try LocalStore.prepareLocation(legacy: source, group: group)
        let unrelated = group.appendingPathComponent("unrelated.txt")
        try Data("keep".utf8).write(to: unrelated)

        try LocalStore.erase(legacy: source, group: group)

        for url in [source, destination] {
            for suffix in ["", "-wal", "-shm"] {
                #expect(!FileManager.default.fileExists(atPath: url.path + suffix))
            }
        }
        #expect(try String(contentsOf: unrelated, encoding: .utf8) == "keep")
        #expect(try LocalStore.prepareLocation(legacy: source, group: group) == destination)
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test func resetAlsoErasesLegacyStoreWhenAppGroupPreparationFailed() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("default.store")
        let invalidGroup = root.appendingPathComponent("not-a-directory")
        try Data("legacy".utf8).write(to: source)
        try Data("keep".utf8).write(to: invalidGroup)
        #expect(throws: (any Error).self) { try LocalStore.prepareLocation(legacy: source, group: invalidGroup) }

        try LocalStore.erase(legacy: source, group: invalidGroup)

        #expect(!FileManager.default.fileExists(atPath: source.path))
        #expect(try String(contentsOf: invalidGroup, encoding: .utf8) == "keep")
    }

    @Test func deterministicWinnersMatchOnDevicesReceivingEqualTimestampDuplicatesInOppositeOrder() throws {
        let first = try deterministicMerge(reverseInsertion: false)
        let second = try deterministicMerge(reverseInsertion: true)
        #expect(first == second)
        #expect(first == ["book-a", "category-a", "session-a", "quote-a", "goal-a"])
    }

    private func deterministicMerge(reverseInsertion: Bool) throws -> [String] {
        let container = try ModelContainer(for: LocalStore.schema, configurations:
            ModelConfiguration(schema: LocalStore.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let category = Models.Category(id: "same-category", name: "Classics", colorHex: nil)
        let session = ReadingSession(id: "same-session", startDate: date, durationSeconds: 600, pagesRead: 10)
        let quote = Quote(id: "same-quote", text: "Text", createdDate: date)
        let goal = ReadingGoal(id: "same-goal", period: .yearly, metric: .books, target: 12, startDate: date)
        var books: [BookTraceShared.LocalLibraryEntryModel] = []
        var goals: [BookTraceShared.LocalReadingGoalModel] = []
        for suffix in ["a", "b"] {
            let categoryRow = BookTraceShared.LocalCategoryModel(category: category)
            categoryRow.rowID = "category-" + suffix
            var entry = LibraryEntry(book: BookReference(id: "gb:same-book", title: suffix), addedDate: date, readingSessions: [session], quotes: [quote])
            entry.notes = suffix
            let book = BookTraceShared.LocalLibraryEntryModel(entry: entry, categories: [categoryRow])
            book.rowID = "book-" + suffix
            book.modifiedDate = date
            book.sessionRecords[0].rowID = "session-" + suffix
            book.quoteRecords[0].rowID = "quote-" + suffix
            books.append(book)
            let goalRow = BookTraceShared.LocalReadingGoalModel(goal: goal)
            goalRow.rowID = "goal-" + suffix
            goalRow.modifiedDate = date
            goals.append(goalRow)
        }
        for book in reverseInsertion ? Array(books.reversed()) : books { context.insert(book) }
        for goal in reverseInsertion ? Array(goals.reversed()) : goals { context.insert(goal) }
        try context.save()
        #expect(try LibraryDeduplicator.run(in: context))
        let book = try #require(context.fetch(FetchDescriptor<BookTraceShared.LocalLibraryEntryModel>()).first)
        let goalRow = try #require(context.fetch(FetchDescriptor<BookTraceShared.LocalReadingGoalModel>()).first)
        #expect(book.title == "a")
        #expect(book.notes == "a\n\nb")
        #expect(book.modifiedDate == date)
        #expect(goalRow.modifiedDate == date)
        #expect(try !LibraryDeduplicator.run(in: context))
        return [book.rowID, try #require(book.categoryRecords.first).rowID,
                try #require(book.sessionRecords.first).rowID, try #require(book.quoteRecords.first).rowID,
                goalRow.rowID]
    }

    @Test func orphanSessionAndQuoteWinnersInheritTheAttachedDuplicatesBook() throws {
        let container = try ModelContainer(for: LocalStore.schema, configurations:
            ModelConfiguration(schema: LocalStore.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let book = BookTraceShared.LocalLibraryEntryModel(entry: LibraryEntry(book: BookReference(id: "gb:parent", title: "Parent")))
        context.insert(book)
        let session = ReadingSession(id: "session", startDate: date, durationSeconds: 600, pagesRead: 10)
        let quote = Quote(id: "quote", text: "Text", createdDate: date)
        for suffix in ["a", "b"] {
            let sessionRow = BookTraceShared.LocalReadingSessionModel(session: session)
            sessionRow.rowID = suffix
            let quoteRow = BookTraceShared.LocalQuoteModel(quote: quote)
            quoteRow.rowID = suffix
            if suffix == "b" {
                sessionRow.libraryEntry = book
                quoteRow.libraryEntry = book
                quoteRow.note = "Retain this note"
                quoteRow.pageNumber = 42
            }
            context.insert(sessionRow)
            context.insert(quoteRow)
        }
        try context.save()

        #expect(try LibraryDeduplicator.run(in: context))

        #expect(book.sessionRecords.map(\.rowID) == ["a"])
        #expect(book.quoteRecords.map(\.rowID) == ["a"])
        #expect(book.toDomain().totalReadSeconds == 600)
        #expect(book.quoteRecords.first?.note == "Retain this note")
        #expect(book.quoteRecords.first?.pageNumber == 42)
    }

    @Test func partiallyImportedIdentityWaitsBeforeChoosingASurvivor() throws {
        let container = try ModelContainer(for: LocalStore.schema, configurations:
            ModelConfiguration(schema: LocalStore.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        defer { withExtendedLifetime(container) {} }
        let entry = LibraryEntry(book: BookReference(id: "gb:pending", title: "Pending"))
        let complete = BookTraceShared.LocalLibraryEntryModel(entry: entry)
        let partial = BookTraceShared.LocalLibraryEntryModel(entry: entry)
        partial.rowID = ""
        container.mainContext.insert(complete)
        container.mainContext.insert(partial)
        try container.mainContext.save()
        #expect(try !LibraryDeduplicator.run(in: container.mainContext))
        #expect(try container.mainContext.fetchCount(FetchDescriptor<BookTraceShared.LocalLibraryEntryModel>()) == 2)
    }
}

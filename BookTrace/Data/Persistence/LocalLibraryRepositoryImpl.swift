//
//  LocalLibraryRepositoryImpl.swift
//  Persistence
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import BookTraceShared
import Foundation
import Models
import SwiftData

enum LocalLibraryRepositoryError: LocalizedError {
    case entryNotFound(String)

    var errorDescription: String? {
        switch self {
        case .entryNotFound(let id):
            "No book with id \(id) was found in your library."
        }
    }
}

/// `LibraryRepository`'nin SwiftData uygulaması.
@MainActor
final class LocalLibraryRepositoryImpl: LibraryRepository {
    private let modelContext: ModelContext
    private let changeNotifier: LibraryChangeNotifier
    private let saveChanges: (ModelContext) throws -> Void

    init(
        modelContext: ModelContext,
        changeNotifier: LibraryChangeNotifier,
        saveChanges: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        self.modelContext = modelContext
        self.changeNotifier = changeNotifier
        self.saveChanges = saveChanges
    }

    func fetchEntries() throws -> [LibraryEntry] {
        var descriptor = FetchDescriptor<LocalLibraryEntryModel>()
        descriptor.sortBy = [SortDescriptor(\.addedDate, order: .reverse)]
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    func fetchCategories() throws -> [Models.Category] {
        var descriptor = FetchDescriptor<LocalCategoryModel>()
        descriptor.sortBy = [SortDescriptor(\.name)]
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    func entry(for bookID: String) throws -> LibraryEntry? {
        try record(for: bookID)?.toDomain()
    }

    func add(_ entry: LibraryEntry) throws {
        // Aynı kitabın ikinci kez eklenmesi bir hata değil; kullanıcının son
        // seçimleri mevcut kaydın üzerine yazılır.
        try mutate {
            var previousCategories: [LocalCategoryModel] = []
            if let existing = try record(for: entry.id) {
                previousCategories = existing.categoryRecords
                existing.apply(entry, categories: try resolveCategories(entry.categories))
                synchronizeChildren(of: existing, with: entry)
            } else {
                modelContext.insert(
                    LocalLibraryEntryModel(entry: entry, categories: try resolveCategories(entry.categories))
                )
            }
            pruneOrphanedCategories(from: previousCategories)
        }
    }

    func update(_ entry: LibraryEntry) throws {
        try mutate {
            guard let record = try record(for: entry.id) else {
                throw LocalLibraryRepositoryError.entryNotFound(entry.id)
            }
            let previousCategories = record.categoryRecords
            record.apply(entry, categories: try resolveCategories(entry.categories))
            synchronizeChildren(of: record, with: entry)
            pruneOrphanedCategories(from: previousCategories)
        }
    }

    func delete(id: String) throws {
        try mutate {
            let descriptor = FetchDescriptor<LocalLibraryEntryModel>(predicate: #Predicate { $0.bookID == id })
            let records = try modelContext.fetch(descriptor)
            guard !records.isEmpty else {
                throw LocalLibraryRepositoryError.entryNotFound(id)
            }
            let previousCategories = records.flatMap(\.categoryRecords)
            // Remove all CloudKit copies of the logical book in one save.
            for record in records { modelContext.delete(record) }
            pruneOrphanedCategories(from: previousCategories)
        }
    }

    func deleteAll() throws {
        // Oturumlar cascade ile, kategoriler kayıt kalmayınca öksüz kalacağı için
        // ayrıca siliniyor.
        // Imported child rows may temporarily have no parent relationship.
        // Explicit deletion includes them; cascade alone cannot erase orphans.
        try mutate {
            for session in try modelContext.fetch(FetchDescriptor<LocalReadingSessionModel>()) { modelContext.delete(session) }
            for quote in try modelContext.fetch(FetchDescriptor<LocalQuoteModel>()) { modelContext.delete(quote) }
            for record in try modelContext.fetch(FetchDescriptor<LocalLibraryEntryModel>()) {
                modelContext.delete(record)
            }
            for category in try modelContext.fetch(FetchDescriptor<LocalCategoryModel>()) {
                modelContext.delete(category)
            }
            for goal in try modelContext.fetch(FetchDescriptor<LocalReadingGoalModel>()) { modelContext.delete(goal) }
        }
    }

    @discardableResult
    func appendSession(_ session: ReadingSession, toEntryWith bookID: String) throws -> LibraryEntry {
        let record = try mutate {
            guard let record = try self.record(for: bookID) else {
                throw LocalLibraryRepositoryError.entryNotFound(bookID)
            }
            // Retrying a completed append must not advance progress again. A
            // later dedup pass could remove duplicate time but cannot undo pages.
            guard !record.sessionRecords.contains(where: { $0.id == session.id }) else { return record }
            var entry = record.toDomain()
            entry.apply(session)
            // Domain limits the stored session to the book's remaining pages.
            let normalizedSession = entry.readingSessions[entry.readingSessions.count - 1]
            let persistedSession = LocalReadingSessionModel(session: normalizedSession)
            persistedSession.libraryEntry = record
            modelContext.insert(persistedSession)
            record.currentPage = entry.currentPage
            record.readingStatusRawValue = entry.readingStatus.rawValue
            record.finishedDate = entry.finishedDate
            record.modifiedDate = Date()
            return record
        }
        return record.toDomain()
    }

    /// Imports and editing preserve session identity; updates never recreate
    /// existing objects or silently discard an exported quote.
    private func synchronizeChildren(of record: LocalLibraryEntryModel, with entry: LibraryEntry) {
        let existingSessions = Set(record.sessionRecords.map(\.id))
        for session in entry.readingSessions where !existingSessions.contains(session.id) {
            let child = LocalReadingSessionModel(session: session)
            child.libraryEntry = record
            contextInsert(child)
        }
        let quotes = Dictionary(record.quoteRecords.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let retained = Set(entry.quotes.map(\.id))
        for child in record.quoteRecords where !retained.contains(child.id) { modelContext.delete(child) }
        for quote in entry.quotes {
            if let child = quotes[quote.id] { child.apply(quote) }
            else {
                let child = LocalQuoteModel(quote: quote)
                child.libraryEntry = record
                modelContext.insert(child)
            }
        }
    }

    private func contextInsert(_ session: LocalReadingSessionModel) { modelContext.insert(session) }

    /// One durable save per operation, including relationship/category cleanup.
    /// On failure rollback also removes pending inserts/deletes; another action
    /// cannot later commit an operation that the UI reported as unsuccessful.
    private func mutate<Value>(_ operation: () throws -> Value) throws -> Value {
        do {
            let result = try operation()
            if modelContext.hasChanges {
                try saveChanges(modelContext)
                changeNotifier.notifyChanged()
            }
            return result
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    /// Only inspect categories explicitly detached by this local operation.
    /// A globally unreferenced category can be awaiting its CloudKit relationship.
    private func pruneOrphanedCategories(from categories: [LocalCategoryModel]) {
        modelContext.processPendingChanges()
        var seen = Set<ObjectIdentifier>()
        for category in categories where seen.insert(ObjectIdentifier(category)).inserted && (category.entries ?? []).isEmpty {
            modelContext.delete(category)
        }
    }

    private func record(for bookID: String) throws -> LocalLibraryEntryModel? {
        var descriptor = FetchDescriptor<LocalLibraryEntryModel>(
            predicate: #Predicate { $0.bookID == bookID }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// Etiketleri kimliğe göre tekilleştirir: aynı ada sahip kategori ikinci kez
    /// yaratılmaz, var olan kayda bağlanır.
    private func resolveCategories(_ categories: [Models.Category]) throws -> [LocalCategoryModel] {
        guard !categories.isEmpty else { return [] }

        let existing = try modelContext.fetch(FetchDescriptor<LocalCategoryModel>())
        var byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        return categories.map { category in
            if let record = byID[category.id] {
                // Var olan etiketin adı korunur: ikinci kitaba farklı yazımla
                // ("deep-work" / "Deep Work") eklemek birincinin adını değiştirmemeli.
                return record
            }
            let record = LocalCategoryModel(category: category)
            modelContext.insert(record)
            byID[category.id] = record
            return record
        }
    }
}

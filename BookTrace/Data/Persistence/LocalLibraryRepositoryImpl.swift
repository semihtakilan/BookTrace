//
//  LocalLibraryRepositoryImpl.swift
//  Persistence
//
//  Created by Semih TAKILAN on 28.08.2026.
//

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

    init(modelContext: ModelContext, changeNotifier: LibraryChangeNotifier) {
        self.modelContext = modelContext
        self.changeNotifier = changeNotifier
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
        if let existing = try record(for: entry.id) {
            existing.apply(entry, categories: try resolveCategories(entry.categories))
        } else {
            modelContext.insert(
                LocalLibraryEntryModel(entry: entry, categories: try resolveCategories(entry.categories))
            )
        }
        try save()
    }

    func update(_ entry: LibraryEntry) throws {
        guard let record = try record(for: entry.id) else {
            throw LocalLibraryRepositoryError.entryNotFound(entry.id)
        }

        record.apply(entry, categories: try resolveCategories(entry.categories))
        try modelContext.save()
        try pruneOrphanedCategories()
        try save()
    }

    func delete(id: String) throws {
        guard let record = try record(for: id) else {
            throw LocalLibraryRepositoryError.entryNotFound(id)
        }

        modelContext.delete(record)
        // İlişkinin güncellenmesi için önce yazılıyor; ardından bu kayıtla
        // birlikte sahipsiz kalan etiketler siliniyor.
        try modelContext.save()
        try pruneOrphanedCategories()
        try save()
    }

    func deleteAll() throws {
        // Oturumlar cascade ile, kategoriler kayıt kalmayınca öksüz kalacağı için
        // ayrıca siliniyor.
        for record in try modelContext.fetch(FetchDescriptor<LocalLibraryEntryModel>()) {
            modelContext.delete(record)
        }
        for category in try modelContext.fetch(FetchDescriptor<LocalCategoryModel>()) {
            modelContext.delete(category)
        }
        try save()
    }

    @discardableResult
    func appendSession(_ session: ReadingSession, toEntryWith bookID: String) throws -> LibraryEntry {
        guard let record = try record(for: bookID) else {
            throw LocalLibraryRepositoryError.entryNotFound(bookID)
        }

        // İlerleme ve durum geçişini Domain'e hesaplatıp sonucu geri yazıyoruz;
        // kural tek yerde kalsın diye.
        var entry = record.toDomain()
        entry.apply(session)

        let persistedSession = LocalReadingSessionModel(session: session)
        persistedSession.libraryEntry = record
        modelContext.insert(persistedSession)

        record.currentPage = entry.currentPage
        record.readingStatusRawValue = entry.readingStatus.rawValue

        try save()
        return record.toDomain()
    }

    /// Kaydeder ve ekranlara tazelenmeleri gerektiğini bildirir.
    private func save() throws {
        try modelContext.save()
        changeNotifier.notifyChanged()
    }

    /// Hiçbir kayda bağlı olmayan etiketleri siler.
    ///
    /// İlişki `.nullify` olduğu için kitap silindiğinde etiket kaydı duruyordu;
    /// kullanıcıya görünmüyordu ama zamanla birikiyordu.
    private func pruneOrphanedCategories() throws {
        let categories = try modelContext.fetch(FetchDescriptor<LocalCategoryModel>())
        for category in categories where category.entries.isEmpty {
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

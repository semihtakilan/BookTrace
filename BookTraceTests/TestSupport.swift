//
//  TestSupport.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation
import Models
import SwiftData
@testable import BookTrace

// MARK: - Fixtures

func makeBook(
    id: String = "book-1",
    title: String = "Dune",
    authors: [String] = ["Frank Herbert"],
    pageCount: Int? = nil,
    description: String? = nil,
    subjects: [String] = []
) -> BookReference {
    BookReference(
        id: id,
        title: title,
        authors: authors,
        pageCount: pageCount,
        description: description,
        subjects: subjects
    )
}

/// Detay zenginleştirmesini sayan sahte kaynak.
actor BookDetailFetchingMock: BookDetailFetching {
    private let description: String?
    private(set) var callCount = 0

    init(description: String? = nil) {
        self.description = description
    }

    func detail(for book: BookReference) async throws -> BookReference {
        callCount += 1
        return book.merging(BookReference(id: book.id, title: book.title, description: description))
    }
}

func makeEntry(
    id: String = "book-1",
    title: String = "Dune",
    authors: [String] = ["Frank Herbert"],
    readingStatus: ReadingStatus = .toRead,
    ownershipStatus: OwnershipStatus = .notOwned,
    pageCount: Int? = nil,
    currentPage: Int = 0,
    categories: [Models.Category] = [],
    addedDate: Date = Date(timeIntervalSince1970: 1_700_000_000),
    sessions: [ReadingSession] = []
) -> LibraryEntry {
    LibraryEntry(
        book: makeBook(id: id, title: title, authors: authors, pageCount: pageCount),
        readingStatus: readingStatus,
        ownershipStatus: ownershipStatus,
        pageCount: nil,
        currentPage: currentPage,
        categories: categories,
        addedDate: addedDate,
        readingSessions: sessions
    )
}

// MARK: - In-memory SwiftData

/// Gerçek şemayı belleğe kuran tek kapsayıcı.
///
/// Test sürecinde uygulama hedefi de kendi `ModelContainer`'ını açıyor; buna ek
/// olarak her test için ayrı bir kapsayıcı kurmak SwiftData'yı çökertiyor.
/// Bu yüzden testler tek bir bellek içi kapsayıcıyı paylaşır — ve bu yüzden
/// `LocalLibraryRepositoryTests` sıralı çalışmak zorunda.
@MainActor
enum TestStore {
    static let container: ModelContainer = {
        do {
            return try ModelContainer(
                for: LocalStore.schema,
                migrationPlan: LibraryMigrationPlan.self,
                configurations: ModelConfiguration(schema: LocalStore.schema, isStoredInMemoryOnly: true)
            )
        } catch {
            fatalError("in-memory ModelContainer could not be created: \(error)")
        }
    }()
}

/// Paylaşılan mağazayı boşaltıp temiz bir repository döndürür.
///
/// Toplu silme (`delete(model:)`) burada kullanılamıyor: kategori ile kayıt
/// arasındaki çok-çoğa ilişkinin nullify kısıtı toplu silmeyi reddediyor.
/// Nesneler tek tek siliniyor — kayıtlar önce, oturumlar onlarla birlikte
/// cascade ile gidiyor.
@MainActor
func makeInMemoryRepository() throws -> (LocalLibraryRepositoryImpl, LibraryChangeNotifier) {
    let context = TestStore.container.mainContext

    for entry in try context.fetch(FetchDescriptor<LocalLibraryEntryModel>()) {
        context.delete(entry)
    }
    for category in try context.fetch(FetchDescriptor<LocalCategoryModel>()) {
        context.delete(category)
    }
    for session in try context.fetch(FetchDescriptor<LocalReadingSessionModel>()) {
        context.delete(session)
    }
    try context.save()

    let notifier = LibraryChangeNotifier()
    return (LocalLibraryRepositoryImpl(modelContext: context, changeNotifier: notifier), notifier)
}

// MARK: - Repository mock

/// Bellekte çalışan `LibraryRepository`. View model testleri SwiftData'ya
/// bağlanmadan çalışsın diye.
@MainActor
final class LibraryRepositoryMock: LibraryRepository {
    var storedEntries: [LibraryEntry] = []
    var storedCategories: [Models.Category] = []
    var errorToThrow: Error?
    private(set) var deletedIDs: [String] = []

    func fetchEntries() throws -> [LibraryEntry] {
        if let errorToThrow { throw errorToThrow }
        return storedEntries.sorted { $0.addedDate > $1.addedDate }
    }

    func fetchCategories() throws -> [Models.Category] {
        if let errorToThrow { throw errorToThrow }
        return storedCategories
    }

    func entry(for bookID: String) throws -> LibraryEntry? {
        if let errorToThrow { throw errorToThrow }
        return storedEntries.first { $0.id == bookID }
    }

    func add(_ entry: LibraryEntry) throws {
        if let errorToThrow { throw errorToThrow }
        if let index = storedEntries.firstIndex(where: { $0.id == entry.id }) {
            storedEntries[index] = entry
        } else {
            storedEntries.append(entry)
        }
    }

    func update(_ entry: LibraryEntry) throws {
        try add(entry)
    }

    func delete(id: String) throws {
        if let errorToThrow { throw errorToThrow }
        deletedIDs.append(id)
        storedEntries.removeAll { $0.id == id }
    }

    func deleteAll() throws {
        if let errorToThrow { throw errorToThrow }
        storedEntries.removeAll()
        storedCategories.removeAll()
    }

    @discardableResult
    func appendSession(_ session: ReadingSession, toEntryWith bookID: String) throws -> LibraryEntry {
        if let errorToThrow { throw errorToThrow }
        guard let index = storedEntries.firstIndex(where: { $0.id == bookID }) else {
            throw LocalLibraryRepositoryError.entryNotFound(bookID)
        }
        storedEntries[index].apply(session)
        return storedEntries[index]
    }
}

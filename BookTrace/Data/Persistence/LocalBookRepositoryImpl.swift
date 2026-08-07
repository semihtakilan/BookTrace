//
//  LocalBookRepositoryImpl.swift
//  BookTrace
//

import Foundation
import Models
import SwiftData

enum LocalBookRepositoryError: LocalizedError {
    case bookNotFound(String)

    var errorDescription: String? {
        switch self {
        case .bookNotFound(let id):
            "Book with id \(id) was not found in the local library."
        }
    }
}

@MainActor
final class LocalBookRepositoryImpl: BookRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func add(_ book: Book) throws {
        guard try record(for: book.id) == nil else {
            try update(book)
            return
        }

        modelContext.insert(LocalBookModel(book: book))
        try modelContext.save()
    }

    func update(_ book: Book) throws {
        guard let record = try record(for: book.id) else {
            throw LocalBookRepositoryError.bookNotFound(book.id)
        }

        record.apply(book)
        try modelContext.save()
    }

    func delete(id: String) throws {
        guard let record = try record(for: id) else {
            throw LocalBookRepositoryError.bookNotFound(id)
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    func fetchBooks() throws -> [Book] {
        let records: [LocalBookModel] = try modelContext.fetch(FetchDescriptor<LocalBookModel>())
        return records
            .map { $0.toDomain() }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func record(for id: String) throws -> LocalBookModel? {
        let records: [LocalBookModel] = try modelContext.fetch(FetchDescriptor<LocalBookModel>())
        return records.first { $0.id == id }
    }
}

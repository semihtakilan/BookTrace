//
//  ReadingWorkspace.swift
//  Release
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import BookTraceShared
import Foundation
import Models
import Observation
import SwiftData

@MainActor
@Observable
final class ReadingWorkspace {
    private(set) var entries: [LibraryEntry] = []
    private(set) var goals: [ReadingGoal] = []
    private(set) var recommendations: [BookReference] = []
    private(set) var statistics = ReadingStatistics(entries: [], year: Calendar.current.component(.year, from: Date()))
    private(set) var yearInReview = YearInReview(entries: [], year: Calendar.current.component(.year, from: Date()))
    var selectedYear = Calendar.current.component(.year, from: Date()) { didSet { rebuild() } }
    var error: UserFacingError?
    private(set) var importProgress: String?
    private(set) var isImporting = false
    private(set) var importSummary: LibraryImportSummary?
    private let repository: any LibraryRepository
    private let context: ModelContext
    private let notifier: LibraryChangeNotifier
    private let search: any BookSearching
    @ObservationIgnored private var recommendedRevision: Int?
    @ObservationIgnored private var recommendationRequest: UUID?
    @ObservationIgnored private var requestingRevision: Int?
    private static let maximumImportBytes = 25_000_000

    init(repository: any LibraryRepository, context: ModelContext, notifier: LibraryChangeNotifier, search: any BookSearching) {
        self.repository = repository
        self.context = context
        self.notifier = notifier
        self.search = search
    }

    func load() { reload(clearError: true) }

    private func reload(clearError: Bool) {
        do {
            let updatedEntries = try repository.fetchEntries()
            let updatedGoals = try context.fetch(FetchDescriptor<LocalReadingGoalModel>())
                .map { $0.toDomain() }.sorted { $0.startDate < $1.startDate }
            entries = updatedEntries
            goals = updatedGoals
            rebuild()
            if clearError { error = nil }
        } catch { self.error = UserFacingError(error) }
    }

    private func rebuild() {
        statistics = ReadingStatistics(entries: entries, year: selectedYear)
        yearInReview = YearInReview(entries: entries, year: selectedYear)
    }

    func save(_ entry: LibraryEntry) {
        do { try repository.update(entry); load() }
        catch { self.error = UserFacingError(error) }
    }

    /// Read immediately before editing so a delayed screen refresh cannot replace
    /// newer sessions, progress, notes, or quotes with an old screen snapshot.
    @discardableResult
    func mutateEntry(bookID: String, _ update: (inout LibraryEntry) throws -> Void) -> Bool {
        do {
            guard var entry = try repository.entry(for: bookID) else {
                throw LocalLibraryRepositoryError.entryNotFound(bookID)
            }
            let original = entry
            try update(&entry)
            if entry != original { try repository.update(entry) }
            load()
            return error == nil
        } catch {
            self.error = UserFacingError(error)
            return false
        }
    }

    @discardableResult
    func mutateQuote(bookID: String, quoteID: String, _ update: (inout Quote) -> Void) -> Bool {
        mutateEntry(bookID: bookID) { entry in
            guard let index = entry.quotes.firstIndex(where: { $0.id == quoteID }) else {
                throw LocalLibraryRepositoryError.entryNotFound(bookID)
            }
            update(&entry.quotes[index])
        }
    }

    func deleteQuote(bookID: String, quoteID: String) {
        mutateEntry(bookID: bookID) { entry in
            guard entry.quotes.contains(where: { $0.id == quoteID }) else {
                throw LocalLibraryRepositoryError.entryNotFound(bookID)
            }
            entry.quotes.removeAll { $0.id == quoteID }
        }
    }

    @discardableResult
    func saveQuote(_ quote: Quote, bookID: String, original: Quote?) -> Bool {
        mutateEntry(bookID: bookID) { entry in
            if let original {
                guard let index = entry.quotes.firstIndex(where: { $0.id == original.id }) else {
                    throw LocalLibraryRepositoryError.entryNotFound(bookID)
                }
                // An unchanged editor field must not overwrite a concurrent edit.
                if quote.text != original.text { entry.quotes[index].text = quote.text }
                if quote.pageNumber != original.pageNumber { entry.quotes[index].pageNumber = quote.pageNumber }
                if quote.note != original.note { entry.quotes[index].note = quote.note }
                if quote.isFavorite != original.isFavorite { entry.quotes[index].isFavorite = quote.isFavorite }
            } else if !entry.quotes.contains(where: { $0.id == quote.id }) {
                // A retry after a saved write and failed refresh keeps one quote.
                entry.quotes.append(quote)
            }
        }
    }

    func saveGoal(_ goal: ReadingGoal) {
        do {
            try persistGoal(goal)
            load()
        } catch { context.rollback(); self.error = UserFacingError(error) }
    }

    private func persistGoal(_ goal: ReadingGoal) throws {
        let id = goal.id
        let descriptor = FetchDescriptor<LocalReadingGoalModel>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first { existing.apply(goal) }
        else { context.insert(LocalReadingGoalModel(goal: goal)) }
        try context.save()
        notifier.notifyChanged()
    }

    func deleteGoal(_ goal: ReadingGoal) {
        do {
            let id = goal.id
            for record in try context.fetch(FetchDescriptor<LocalReadingGoalModel>(predicate: #Predicate { $0.id == id })) { context.delete(record) }
            try context.save()
            notifier.notifyChanged()
            load()
        } catch { context.rollback(); self.error = UserFacingError(error) }
    }

    func loadRecommendations() async {
        let revision = notifier.revision
        guard recommendedRevision != revision, requestingRevision != revision else { return }
        let library: [LibraryEntry]
        do { library = try repository.fetchEntries() }
        catch { return }
        let request = UUID()
        recommendationRequest = request
        requestingRevision = revision
        defer {
            if recommendationRequest == request {
                requestingRevision = nil
                recommendationRequest = nil
            }
        }
        let subjects = RecommendationEngine.preferredSubjects(in: library)
        guard !subjects.isEmpty else { recommendations = []; recommendedRevision = revision; return }
        var candidates: [BookReference] = []
        var allSucceeded = true
        for subject in subjects {
            guard !Task.isCancelled, recommendationRequest == request, notifier.revision == revision else { return }
            do { candidates += try await search.books(inSubject: subject, maxResults: 15) }
            catch is CancellationError { return }
            catch { allSucceeded = false }
        }
        // An old request can complete after the user adds, rates or removes a book.
        // It must neither overwrite a newer result nor mark that new revision done.
        guard !Task.isCancelled, recommendationRequest == request, notifier.revision == revision else { return }
        recommendations = RecommendationEngine.recommend(candidates: candidates, library: library)
        if allSucceeded { recommendedRevision = revision }
    }

    func export(json: Bool) throws -> URL {
        // Read the repository at export time, including edits made since this screen
        // last appeared. Never silently export an obsolete in-memory snapshot.
        let latestEntries = try repository.fetchEntries()
        let latestGoals = try context.fetch(FetchDescriptor<LocalReadingGoalModel>()).map { $0.toDomain() }
        let data = json ? try LibraryBackupCodec.encode(entries: latestEntries, goals: latestGoals)
                        : Data(GoodreadsCSVCodec.encode(latestEntries).utf8)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("BookTrace-exports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("BookTrace-\(UUID().uuidString).\(json ? "json" : "csv")")
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        error = nil
        return url
    }

    /// Decode and preview before mutating the library. Bound the read itself: file
    /// metadata alone can be stale if another process grows the document meanwhile.
    func decodeImport(_ url: URL) throws -> LibraryBackup {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard url.isFileURL else { throw ImportError.invalidText }
        let attributes = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard attributes.isRegularFile == true else { throw ImportError.invalidText }
        guard (attributes.fileSize ?? 0) <= Self.maximumImportBytes else { throw ImportError.tooLarge }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while data.count <= Self.maximumImportBytes {
            let remaining = Self.maximumImportBytes + 1 - data.count
            guard let chunk = try handle.read(upToCount: min(65_536, remaining)), !chunk.isEmpty else { break }
            data.append(chunk)
        }
        guard data.count <= Self.maximumImportBytes else { throw ImportError.tooLarge }
        let result: LibraryBackup
        if url.pathExtension.lowercased() == "json" { result = try LibraryBackupCodec.decode(data) }
        else {
            guard let csv = String(data: data, encoding: .utf8) else { throw ImportError.invalidText }
            result = LibraryBackup(entries: try GoodreadsCSVCodec.decode(csv), goals: [])
        }
        error = nil
        return result
    }

    func importLibrary(_ backup: LibraryBackup) async {
        guard !isImporting else { return }
        isImporting = true
        error = nil
        importSummary = nil
        var addedBooks = 0
        var mergedBooks = 0
        var addedGoals = 0
        var outcome: LibraryImportSummary.Outcome = .completed
        defer {
            isImporting = false
            importProgress = nil
            importSummary = LibraryImportSummary(outcome: outcome, addedBooks: addedBooks, mergedBooks: mergedBooks, addedGoals: addedGoals)
            // A successful reload must not erase an error from a partial import.
            reload(clearError: false)
        }
        do {
            var index = ImportIdentityIndex(try repository.fetchEntries())
            var indexedRevision = notifier.revision
            var resolvedISBNs: [String: BookReference] = [:]
            for (offset, imported) in backup.entries.enumerated() {
                // JSON and ISBN-less rows have no network suspension. Give the
                // main run loop time to show progress and handle Stop between batches.
                if offset.isMultiple(of: 20) { try await Task.sleep(for: .milliseconds(1)) }
                try Task.checkCancellation()
                importProgress = "\(offset + 1) / \(backup.entries.count)"
                var entry = imported
                if let isbn = entry.book.isbn13, entry.book.source == .local {
                    if let resolved = resolvedISBNs[isbn] { entry.book = resolved.merging(entry.book) }
                    else {
                        // Root injects the cached Open Library-first catalog. One
                        // lookup at a time keeps bulk migration within its budget.
                        do {
                            let resolved = try await search.findBook(isbn: isbn)
                            resolvedISBNs[isbn] = resolved
                            entry.book = resolved.merging(entry.book)
                        } catch is CancellationError { throw CancellationError() }
                        catch { /* Offline imports retain the CSV metadata. */ }
                    }
                }
                try Task.checkCancellation()
                if notifier.revision != indexedRevision {
                    index = ImportIdentityIndex(try repository.fetchEntries())
                }
                if var existing = index.existing(for: entry.book) {
                    var sessionIDs = Set(existing.readingSessions.map(\.id))
                    existing.readingSessions += entry.readingSessions.filter { sessionIDs.insert($0.id).inserted }
                    var quoteIDs = Set(existing.quotes.map(\.id))
                    existing.quotes += entry.quotes.filter { quoteIDs.insert($0.id).inserted }
                    try repository.update(existing)
                    index.include(existing)
                    // Keep aliases from this source so the next batch row matches
                    // even if the catalog resolved it to another canonical ID.
                    index.alias(entry.book, to: existing.id)
                    mergedBooks += 1
                } else {
                    var sessionIDs = Set<String>()
                    entry.readingSessions = entry.readingSessions.filter { sessionIDs.insert($0.id).inserted }
                    var quoteIDs = Set<String>()
                    entry.quotes = entry.quotes.filter { quoteIDs.insert($0.id).inserted }
                    try repository.add(entry)
                    index.include(entry)
                    addedBooks += 1
                }
                indexedRevision = notifier.revision
            }
            var goalIDs = Set(try context.fetch(FetchDescriptor<LocalReadingGoalModel>()).map(\.id))
            for (offset, goal) in backup.goals.enumerated() {
                if offset.isMultiple(of: 20) {
                    try await Task.sleep(for: .milliseconds(1))
                    goalIDs = Set(try context.fetch(FetchDescriptor<LocalReadingGoalModel>()).map(\.id))
                }
                try Task.checkCancellation()
                guard goalIDs.insert(goal.id).inserted else { continue }
                try persistGoal(goal)
                addedGoals += 1
            }
        } catch is CancellationError { outcome = .cancelled }
        catch {
            outcome = .failed
            context.rollback()
            self.error = UserFacingError(error)
        }
    }

    enum ImportError: LocalizedError, Equatable {
        case tooLarge, invalidText
        var errorDescription: String? {
            switch self {
            case .tooLarge: String(localized: "Choose a backup smaller than 25 MB.")
            case .invalidText: String(localized: "This file could not be read as UTF-8 text.")
            }
        }
    }
}

nonisolated struct LibraryImportSummary: Equatable, Sendable {
    enum Outcome: Equatable, Sendable { case completed, cancelled, failed }
    let outcome: Outcome
    let addedBooks: Int
    let mergedBooks: Int
    let addedGoals: Int
}

private struct ImportIdentityIndex {
    private var entries: [String: LibraryEntry] = [:]
    private var aliases: [String: String] = [:]

    init(_ library: [LibraryEntry]) { for entry in library { include(entry) } }

    func existing(for book: BookReference) -> LibraryEntry? {
        for key in keys(book) {
            if let id = aliases[key], let entry = entries[id] { return entry }
        }
        return nil
    }

    mutating func include(_ entry: LibraryEntry) {
        entries[entry.id] = entry
        alias(entry.book, to: entry.id)
    }

    mutating func alias(_ book: BookReference, to id: String) {
        for key in keys(book) where aliases[key] == nil { aliases[key] = id }
    }

    private func keys(_ book: BookReference) -> [String] {
        var values = ["id:" + book.id]
        if let isbn = book.isbn13?.filter(\.isNumber), !isbn.isEmpty { values.append("isbn:" + isbn) }
        // Matching an empty title would conflate unrelated metadata-only rows.
        if !book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            values.append("work:" + book.matchingKey)
        }
        return values
    }
}

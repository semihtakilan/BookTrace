//
//  ReadingWorkspaceTests.swift
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
struct ReadingWorkspaceTests {
    @Test func oversizedFileIsRejectedBeforeReadingItsSparseContents() throws {
        let workspace = makeWorkspace(repository: LibraryRepositoryMock())
        let url = temporaryURL(extension: "json")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(FileManager.default.createFile(atPath: url.path, contents: nil))
        let file = try FileHandle(forWritingTo: url)
        try file.truncate(atOffset: 25_000_001)
        try file.close()
        #expect(throws: ReadingWorkspace.ImportError.tooLarge) { try workspace.decodeImport(url) }
    }

    @Test func sameBatchISBNAndSessionDuplicatesAreMergedWithoutResettingProgress() async throws {
        let repository = LibraryRepositoryMock()
        let workspace = makeWorkspace(repository: repository)
        let session = ReadingSession(id: "session", startDate: .now, durationSeconds: 90, pagesRead: 3)
        let quote = Quote(id: "quote", text: "A remembered line")
        let first = LibraryEntry(book: BookReference(id: "gb:first", title: "Original title", authors: ["Author"], isbn13: "978-0-123456-78-9"),
                                 currentPage: 35, readingSessions: [session], notes: "Keep my note", quotes: [quote])
        let second = LibraryEntry(book: BookReference(id: "ol:second", title: "Other catalog title", authors: ["Author"], isbn13: "9780123456789"),
                                  currentPage: 0, readingSessions: [session, session], quotes: [quote, Quote(id: "q2", text: "New quote"), Quote(id: "q2", text: "Duplicate")])
        await workspace.importLibrary(LibraryBackup(entries: [first, second], goals: []))
        let entry = try #require(repository.storedEntries.first)
        #expect(repository.storedEntries.count == 1)
        #expect(entry.id == "gb:first")
        #expect(entry.currentPage == 35)
        #expect(entry.notes == "Keep my note")
        #expect(entry.readingSessions.count == 1)
        #expect(entry.quotes.map(\.id) == ["quote", "q2"])
        #expect(workspace.importSummary == LibraryImportSummary(outcome: .completed, addedBooks: 1, mergedBooks: 1, addedGoals: 0))
    }

    @Test func sameBatchMatchesTitleAndAuthorWhenISBNIsAbsent() async {
        let repository = LibraryRepositoryMock()
        let workspace = makeWorkspace(repository: repository)
        let first = LibraryEntry(book: BookReference(id: "gb:a", title: "Dune!", authors: ["Frank Herbert"]))
        let second = LibraryEntry(book: BookReference(id: "ol:b", title: "dune", authors: ["FRANK HERBERT"]))
        await workspace.importLibrary(LibraryBackup(entries: [first, second], goals: []))
        #expect(repository.storedEntries.count == 1)
        #expect(workspace.importSummary?.mergedBooks == 1)
    }

    @Test func offlineMetadataLookupDoesNotPreventImportOrLeaveAStaleError() async {
        let repository = LibraryRepositoryMock()
        let workspace = makeWorkspace(repository: repository)
        workspace.error = .timedOut
        let entry = LibraryEntry(book: BookReference(id: "local:csv-row", title: "Offline book", isbn13: "9780123456789"))
        await workspace.importLibrary(LibraryBackup(entries: [entry], goals: []))
        #expect(repository.storedEntries.first?.book.title == "Offline book")
        #expect(workspace.error == nil)
        #expect(workspace.importSummary?.outcome == .completed)
        #expect(!workspace.isImporting)
        #expect(workspace.importProgress == nil)
    }

    @Test func successfulReloadAndSaveClearPreviousErrors() {
        let repository = LibraryRepositoryMock()
        let workspace = makeWorkspace(repository: repository)
        workspace.error = .offline
        workspace.load()
        #expect(workspace.error == nil)
        workspace.error = .unknown
        workspace.save(LibraryEntry(book: BookReference(id: "gb:edit", title: "Edited")))
        #expect(workspace.error == nil)
    }

    @Test func importFailureRemainsVisibleAfterFinalReload() async {
        let repository = LibraryRepositoryMock()
        repository.errorToThrow = URLError(.notConnectedToInternet)
        let workspace = makeWorkspace(repository: repository)
        await workspace.importLibrary(LibraryBackup(entries: [LibraryEntry(book: BookReference(id: "gb:book", title: "Book"))], goals: []))
        #expect(workspace.error == .offline)
        #expect(workspace.importSummary?.outcome == .failed)
        #expect(!workspace.isImporting)
    }

    @Test func exportReadsCurrentRepositoryInsteadOfTheLastScreenSnapshot() throws {
        let repository = LibraryRepositoryMock()
        repository.storedEntries = [LibraryEntry(book: BookReference(id: "gb:book", title: "Before"))]
        let workspace = makeWorkspace(repository: repository)
        workspace.load()
        repository.storedEntries[0].notes = "Saved from another screen"
        let url = try workspace.export(json: true)
        defer { try? FileManager.default.removeItem(at: url) }
        let backup = try LibraryBackupCodec.decode(Data(contentsOf: url))
        #expect(backup.entries.first?.notes == "Saved from another screen")
    }

    @Test func personalDraftSurvivesReturningFromChildNavigation() {
        var entry = LibraryEntry(book: BookReference(id: "gb:book", title: "Book"), rating: 2, notes: "Original")
        var draft = PersonalBookDraft()
        draft.load(entry)
        draft.notes = "Unsaved words"
        draft.rating = 4
        entry.notes = "New remote words"
        entry.rating = 5
        draft.load(entry)
        #expect(draft.notes == "Unsaved words")
        #expect(draft.rating == 4)
        draft.apply(to: &entry)
        #expect(entry.notes == "Unsaved words")
        #expect(entry.rating == 4)
    }

    @Test func personalEditPreservesNewProgressQuotesAndUnchangedPersonalFields() throws {
        let repository = LibraryRepositoryMock()
        let original = LibraryEntry(book: BookReference(id: "gb:book", title: "Book", pageCount: 200),
                                    currentPage: 10, notes: "Original")
        repository.storedEntries = [original]
        let workspace = makeWorkspace(repository: repository)
        workspace.load()
        var draft = PersonalBookDraft()
        draft.load(original)
        draft.notes = "My edited note"
        let session = ReadingSession(startDate: .now, durationSeconds: 120, pagesRead: 5)
        let quote = Quote(text: "A new quote from another device")
        repository.storedEntries[0].currentPage = 65
        repository.storedEntries[0].readingSessions = [session]
        repository.storedEntries[0].quotes = [quote]
        repository.storedEntries[0].rating = 5
        repository.storedEntries[0].isFavorite = true

        #expect(workspace.mutateEntry(bookID: original.id) { entry in draft.apply(to: &entry) })
        let saved = try #require(repository.storedEntries.first)
        #expect(saved.notes == "My edited note")
        #expect(saved.currentPage == 65)
        #expect(saved.readingSessions == [session])
        #expect(saved.quotes == [quote])
        #expect(saved.rating == 5)
        #expect(saved.isFavorite)
    }

    @Test func quoteEditPreservesConcurrentFieldsAndOtherQuotes() throws {
        let repository = LibraryRepositoryMock()
        let original = Quote(id: "quote", text: "Original text")
        repository.storedEntries = [LibraryEntry(book: BookReference(id: "gb:book", title: "Book"), quotes: [original])]
        let workspace = makeWorkspace(repository: repository)
        workspace.load()
        let newQuote = Quote(id: "new", text: "Arrived while editing")
        repository.storedEntries[0].quotes[0].note = "Remote note"
        repository.storedEntries[0].quotes[0].pageNumber = 22
        repository.storedEntries[0].quotes[0].isFavorite = true
        repository.storedEntries[0].quotes.append(newQuote)
        repository.storedEntries[0].currentPage = 80
        repository.storedEntries[0].rating = 4
        var edited = original
        edited.text = "Edited text"

        #expect(workspace.saveQuote(edited, bookID: "gb:book", original: original))
        let saved = try #require(repository.storedEntries.first)
        #expect(saved.currentPage == 80)
        #expect(saved.rating == 4)
        #expect(saved.quotes[0].text == "Edited text")
        #expect(saved.quotes[0].note == "Remote note")
        #expect(saved.quotes[0].pageNumber == 22)
        #expect(saved.quotes[0].isFavorite)
        #expect(saved.quotes[1] == newQuote)

        // Toggling and deleting also fetch the current record, not the list row.
        repository.storedEntries[0].quotes[0].note = "Even newer note"
        #expect(workspace.mutateQuote(bookID: "gb:book", quoteID: original.id) { $0.isFavorite.toggle() })
        #expect(repository.storedEntries[0].quotes[0].note == "Even newer note")
        #expect(!repository.storedEntries[0].quotes[0].isFavorite)
        workspace.deleteQuote(bookID: "gb:book", quoteID: original.id)
        #expect(repository.storedEntries[0].quotes == [newQuote])
        #expect(repository.storedEntries[0].currentPage == 80)
    }

    @Test func editingADeletedBookDoesNotRestoreIt() {
        let repository = LibraryRepositoryMock()
        repository.storedEntries = [LibraryEntry(book: BookReference(id: "gb:gone", title: "Gone"))]
        let workspace = makeWorkspace(repository: repository)
        workspace.load()
        repository.storedEntries = []
        #expect(!workspace.mutateEntry(bookID: "gb:gone") { $0.notes = "Unsaved note" })
        #expect(workspace.error == .notInLibrary)
        #expect(!workspace.saveQuote(Quote(text: "New quote"), bookID: "gb:gone", original: nil))
        #expect(repository.storedEntries.isEmpty)
    }

    @Test func editingADeletedQuoteDoesNotRestoreIt() {
        let repository = LibraryRepositoryMock()
        let original = Quote(id: "gone", text: "Gone")
        repository.storedEntries = [LibraryEntry(book: BookReference(id: "gb:book", title: "Book"), quotes: [original])]
        let workspace = makeWorkspace(repository: repository)
        workspace.load()
        repository.storedEntries[0].quotes = []
        var edited = original
        edited.text = "Unsaved text"
        #expect(!workspace.saveQuote(edited, bookID: "gb:book", original: original))
        #expect(!workspace.mutateQuote(bookID: "gb:book", quoteID: original.id) { $0.isFavorite.toggle() })
        workspace.deleteQuote(bookID: "gb:book", quoteID: original.id)
        #expect(workspace.error == .notInLibrary)
        #expect(repository.storedEntries[0].quotes.isEmpty)
    }

    @Test func retryingNewQuoteSaveKeepsItsIdentityAndNewerEdits() {
        let repository = LibraryRepositoryMock()
        repository.storedEntries = [LibraryEntry(book: BookReference(id: "gb:book", title: "Book"))]
        let workspace = makeWorkspace(repository: repository)
        let draft = Quote(id: "stable-draft", text: "Quote")
        #expect(workspace.saveQuote(draft, bookID: "gb:book", original: nil))
        repository.storedEntries[0].quotes[0].note = "Changed after the first write"
        #expect(workspace.saveQuote(draft, bookID: "gb:book", original: nil))
        #expect(repository.storedEntries[0].quotes.count == 1)
        #expect(repository.storedEntries[0].quotes[0].note == "Changed after the first write")
    }

    @Test func importWithoutNetworkCanBeStoppedBetweenCommittedBatches() async throws {
        let repository = LibraryRepositoryMock()
        let workspace = makeWorkspace(repository: repository)
        let entries = (0..<200).map { index in
            LibraryEntry(book: BookReference(id: "gb:book-\(index)", title: "Book \(index)"))
        }
        let task = Task { await workspace.importLibrary(LibraryBackup(entries: entries)) }
        for _ in 0..<1_000 {
            if !repository.storedEntries.isEmpty { break }
            try await Task.sleep(for: .milliseconds(1))
        }
        task.cancel()
        await task.value
        #expect(!repository.storedEntries.isEmpty)
        #expect(repository.storedEntries.count < entries.count)
        #expect(workspace.importSummary?.outcome == .cancelled)
        #expect(workspace.importSummary?.addedBooks == repository.storedEntries.count)
        #expect(workspace.error == nil)
        #expect(!workspace.isImporting)
    }

    @Test func cancellationAfterISBNLookupDoesNotPersistThePendingRow() async {
        let repository = LibraryRepositoryMock()
        let catalog = WorkspaceControlledCatalog()
        let workspace = makeWorkspace(repository: repository, search: catalog)
        let entry = LibraryEntry(book: BookReference(id: "local:pending", title: "Pending", isbn13: "9780123456789"))
        let task = Task { await workspace.importLibrary(LibraryBackup(entries: [entry], goals: [])) }
        await catalog.waitForRequest("9780123456789")
        task.cancel()
        await catalog.complete("9780123456789", books: [BookReference(id: "ol:resolved", title: "Resolved")])
        await task.value
        #expect(repository.storedEntries.isEmpty)
        #expect(workspace.importSummary?.outcome == .cancelled)
        #expect(workspace.error == nil)
        #expect(!workspace.isImporting)
    }

    @Test func oldRecommendationsCannotOverwriteANewerLibraryRevision() async {
        let repository = LibraryRepositoryMock()
        let catalog = WorkspaceControlledCatalog()
        let notifier = LibraryChangeNotifier()
        repository.storedEntries = [LibraryEntry(book: BookReference(id: "gb:science", title: "Science", subjects: ["science"]), readingStatus: .reading)]
        let workspace = makeWorkspace(repository: repository, search: catalog, notifier: notifier)
        workspace.load()
        let oldTask = Task { await workspace.loadRecommendations() }
        await catalog.waitForRequest("science")
        repository.storedEntries = [LibraryEntry(book: BookReference(id: "gb:fantasy", title: "Fantasy", subjects: ["fantasy"]), readingStatus: .reading)]
        notifier.notifyChanged()
        workspace.load()
        let newTask = Task { await workspace.loadRecommendations() }
        await catalog.waitForRequest("fantasy")
        await catalog.complete("fantasy", books: [BookReference(id: "ol:new", title: "New suggestion", subjects: ["fantasy"])])
        await newTask.value
        await catalog.complete("science", books: [BookReference(id: "ol:old", title: "Old suggestion", subjects: ["science"])])
        await oldTask.value
        #expect(workspace.recommendations.map(\.id) == ["ol:new"])
    }

    private func makeWorkspace(
        repository: LibraryRepositoryMock,
        search: any BookSearching = WorkspaceOfflineCatalog(),
        notifier: LibraryChangeNotifier = LibraryChangeNotifier()
    ) -> ReadingWorkspace {
        ReadingWorkspace(repository: repository, context: ModelContext(TestStore.container), notifier: notifier, search: search)
    }

    private func temporaryURL(extension suffix: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("workspace-test-\(UUID().uuidString).\(suffix)")
    }
}

private actor WorkspaceOfflineCatalog: BookSearching {
    func searchBooks(query: String, maxResults: Int) async throws -> [BookReference] { [] }
    func books(inSubject subject: String, maxResults: Int) async throws -> [BookReference] { [] }
    func findBook(isbn: String) async throws -> BookReference { throw URLError(.notConnectedToInternet) }
}

private actor WorkspaceControlledCatalog: BookSearching {
    private var requests: [String: CheckedContinuation<[BookReference], any Error>] = [:]
    private var observers: [String: CheckedContinuation<Void, Never>] = [:]
    func searchBooks(query: String, maxResults: Int) async throws -> [BookReference] {
        try await withCheckedThrowingContinuation { continuation in
            requests[query] = continuation
            observers.removeValue(forKey: query)?.resume()
        }
    }
    func books(inSubject subject: String, maxResults: Int) async throws -> [BookReference] {
        try await searchBooks(query: subject, maxResults: maxResults)
    }
    func findBook(isbn: String) async throws -> BookReference {
        let books = try await searchBooks(query: isbn, maxResults: 1)
        guard let book = books.first else { throw URLError(.resourceUnavailable) }
        return book
    }
    func waitForRequest(_ key: String) async {
        guard requests[key] == nil else { return }
        await withCheckedContinuation { observers[key] = $0 }
    }
    func complete(_ key: String, books: [BookReference]) {
        requests.removeValue(forKey: key)?.resume(returning: books)
    }
}

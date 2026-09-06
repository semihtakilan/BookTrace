//
//  BooksViewModelTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation
import Models
import Testing
@testable import BookTrace

@MainActor
struct BooksViewModelTests {

    private func makeViewModel(_ entries: [LibraryEntry]) -> (BooksViewModel, LibraryRepositoryMock) {
        let repository = LibraryRepositoryMock()
        repository.storedEntries = entries
        let viewModel = BooksViewModel(libraryRepository: repository)
        viewModel.load()
        return (viewModel, repository)
    }

    private var library: [LibraryEntry] {
        [
            makeEntry(id: "a", title: "Dune", authors: ["Frank Herbert"],
                      readingStatus: .reading, ownershipStatus: .owned, pageCount: 400, currentPage: 100,
                      categories: [Models.Category(name: "Favorites")],
                      addedDate: Date(timeIntervalSince1970: 3_000)),
            makeEntry(id: "b", title: "Neuromancer", authors: ["William Gibson"],
                      readingStatus: .toRead, ownershipStatus: .owned, pageCount: 300,
                      addedDate: Date(timeIntervalSince1970: 2_000)),
            makeEntry(id: "c", title: "Anathem", authors: ["Neal Stephenson"],
                      readingStatus: .finished, ownershipStatus: .notOwned, pageCount: 900, currentPage: 900,
                      addedDate: Date(timeIntervalSince1970: 1_000))
        ]
    }

    // MARK: - Gruplama

    @Test func groupingByStatusListsEachBookExactlyOnce() {
        let (viewModel, _) = makeViewModel(library)
        viewModel.grouping = .status

        let ids = viewModel.sections.flatMap { $0.entries.map(\.id) }
        #expect(ids.sorted() == ["a", "b", "c"])
        #expect(viewModel.sections.map(\.kind) == [
            .status(.reading), .status(.toRead), .status(.finished)
        ])
    }

    @Test func groupingByEverythingPutsAllBooksInOneSection() {
        let (viewModel, _) = makeViewModel(library)
        viewModel.grouping = .all

        #expect(viewModel.sections.count == 1)
        #expect(viewModel.sections[0].kind == .all)
        #expect(viewModel.sections[0].entries.count == 3)
    }

    @Test func booksWithoutTagsGetTheirOwnSectionInsteadOfDisappearing() {
        let (viewModel, _) = makeViewModel(library)
        viewModel.grouping = .category

        #expect(viewModel.sections.map(\.kind) == [
            .category(Models.Category(name: "Favorites")), .untagged
        ])
        #expect(viewModel.sections.last?.entries.map(\.id).sorted() == ["b", "c"])
    }

    @Test func everyGroupingKeepsReadingBooksInTheSearchableShelf() {
        var entries = library
        entries[1].categories = [Models.Category(name: "Favorites")]
        let (viewModel, _) = makeViewModel(entries)
        for grouping in LibraryGrouping.allCases {
            viewModel.grouping = grouping
            #expect(viewModel.nowReading.map(\.id) == ["a"])
            #expect(viewModel.sections.flatMap(\.entries).map(\.id).sorted() == ["a", "b", "c"])
        }
    }

    @Test func emptyGroupsAreLeftOut() {
        let (viewModel, _) = makeViewModel([library[0]])
        viewModel.grouping = .ownership

        #expect(viewModel.sections.map(\.kind) == [.ownership(.owned)])
        #expect(viewModel.nowReading.map(\.id) == ["a"])
    }

    // MARK: - Arama

    @Test func searchMatchesTitleAuthorAndTag() {
        let (viewModel, _) = makeViewModel(library)
        viewModel.grouping = .all

        viewModel.searchText = "neuro"
        #expect(viewModel.sections.flatMap { $0.entries.map(\.id) } == ["b"])

        viewModel.searchText = "gibson"
        #expect(viewModel.sections.flatMap { $0.entries.map(\.id) } == ["b"])

        viewModel.searchText = "favorites"
        #expect(viewModel.sections.flatMap(\.entries).map(\.id) == ["a"])
        #expect(viewModel.nowReading.map(\.id) == ["a"])
    }

    @Test func aSearchThatMatchesNothingIsNotAnEmptyLibrary() {
        let (viewModel, _) = makeViewModel(library)

        viewModel.searchText = "zzz"

        #expect(viewModel.sections.isEmpty)
        #expect(viewModel.hasNoMatches)
        #expect(!viewModel.isEmpty)
    }

    @Test func searchFocusesResultsAndHidesUnfilteredReadingShortcuts() {
        let (viewModel, _) = makeViewModel(library)
        #expect(viewModel.isShowingNowReading)
        #expect(viewModel.nowReading.map(\.id) == ["a"])

        viewModel.searchText = "dune"
        #expect(!viewModel.isShowingNowReading)
        #expect(viewModel.sections.flatMap(\.entries).map(\.id) == ["a"])
    }

    // MARK: - Sıralama

    @Test func statusFilterCombinesWithSearchAndCanBeCleared() {
        let (viewModel, _) = makeViewModel(library)
        viewModel.statusFilter = .toRead
        #expect(viewModel.sections.flatMap(\.entries).map(\.id) == ["b"])
        #expect(!viewModel.isShowingNowReading)

        viewModel.searchText = "Dune"
        #expect(viewModel.hasNoMatches)
        #expect(!viewModel.isEmpty)
        viewModel.statusFilter = nil
        #expect(viewModel.sections.flatMap(\.entries).map(\.id) == ["a"])
        #expect(viewModel.nowReading.map(\.id) == ["a"])

        viewModel.searchText = ""
        #expect(viewModel.isShowingNowReading)
        #expect(viewModel.sections.flatMap(\.entries).count == 3)

        viewModel.grouping = .category
        #expect(viewModel.isShowingNowReading)
        #expect(viewModel.sections.flatMap(\.entries).contains { $0.readingStatus == .reading })
    }

    @Test func sortingIsAppliedWithinEverySection() {
        let (viewModel, _) = makeViewModel(library)
        viewModel.grouping = .all

        viewModel.sort = .title
        #expect(viewModel.sections[0].entries.map(\.book.title) == ["Anathem", "Dune", "Neuromancer"])

        viewModel.sort = .recentlyAdded
        #expect(viewModel.sections[0].entries.map(\.id) == ["a", "b", "c"])

        viewModel.sort = .progress
        #expect(viewModel.sections[0].entries.map(\.id) == ["c", "a", "b"])
    }

    @Test func anEntirelyReadingLibraryStillHasASearchableShelf() {
        let (viewModel, _) = makeViewModel([library[0]])
        #expect(viewModel.shelfCount == 1)
        #expect(viewModel.matchingCount == 1)
        #expect(BooksViewModel.shelfStatuses.contains(.reading))

        viewModel.searchText = "Frank Herbert"
        viewModel.statusFilter = .reading
        #expect(viewModel.sections.flatMap(\.entries).map(\.id) == ["a"])
        #expect(!viewModel.hasNoMatches)

        viewModel.searchText = "unknown"
        #expect(viewModel.hasNoMatches)
        viewModel.clearFilters()
        #expect(viewModel.matchingCount == 1)
        #expect(viewModel.isShowingNowReading)
    }

    @Test func filterCountsDescribeTheSearchAndResultCountDoesNotDuplicateTags() {
        var entry = library[0]
        entry.categories = [Models.Category(name: "Favorites"), Models.Category(name: "Fiction")]
        let (viewModel, _) = makeViewModel([entry] + library.dropFirst())
        viewModel.grouping = .category
        #expect(viewModel.sections.flatMap(\.entries).count == 4)
        #expect(viewModel.matchingCount == 3)

        viewModel.searchText = "Dune"
        #expect(viewModel.searchMatchCount == 1)
        #expect(viewModel.count(for: .reading) == 1)
        #expect(viewModel.count(for: .finished) == 0)
        #expect(viewModel.matchingCount == 1)
        viewModel.statusFilter = .finished
        #expect(viewModel.matchingCount == 0)
        #expect(viewModel.hasNoMatches)
    }

    @Test func continueReadingPrioritizesLatestSessionRegardlessOfShelfSort() {
        let recentlyRead = makeEntry(id: "recent", title: "Zebra", readingStatus: .reading,
                                    sessions: [ReadingSession(startDate: Date(), durationSeconds: 600, pagesRead: 5)])
        let (viewModel, _) = makeViewModel(library + [recentlyRead])
        viewModel.sort = .title
        #expect(viewModel.nowReading.first?.id == "recent")
        viewModel.sort = .progress
        #expect(viewModel.nowReading.first?.id == "recent")
    }

    @Test func changingStatusUsesLatestStoredProgressAndRefreshesEveryShelf() throws {
        let (viewModel, repository) = makeViewModel(library)
        let stale = library[0]
        try repository.appendSession(ReadingSession(startDate: Date(), durationSeconds: 600, pagesRead: 20),
                                     toEntryWith: stale.id)
        viewModel.update(readingStatus: .abandoned, for: stale)
        let updated = try #require(try repository.entry(for: stale.id))
        #expect(updated.currentPage == 120)
        #expect(updated.readingSessions.count == 1)
        #expect(updated.readingStatus == .abandoned)
        #expect(viewModel.nowReading.isEmpty)
        #expect(viewModel.count(for: .abandoned) == 1)
    }

    @Test func movingAFinishedBookToReadingPreservesProgressAndRecordedHistory() throws {
        let session = ReadingSession(startDate: Date(), durationSeconds: 600, pagesRead: 10)
        let finished = makeEntry(readingStatus: .finished, pageCount: 300, sessions: [session])
        let (viewModel, repository) = makeViewModel([finished])

        viewModel.update(readingStatus: .reading, for: finished)

        let updated = try #require(try repository.entry(for: finished.id))
        #expect(updated.currentPage == 300)
        #expect(updated.readingSessions == [session])
        #expect(viewModel.nowReading.map(\.id) == [finished.id])
    }

    // MARK: - Silme

    @Test func deletingAlwaysWaitsForConfirmation() throws {
        let (viewModel, repository) = makeViewModel(library)
        let dune = try #require(library.first)

        viewModel.requestDeletion(of: dune)
        #expect(viewModel.pendingDeletion?.id == "a")
        #expect(repository.deletedIDs.isEmpty)

        viewModel.cancelDeletion()
        #expect(viewModel.pendingDeletion == nil)
        #expect(repository.deletedIDs.isEmpty)

        viewModel.requestDeletion(of: dune)
        viewModel.confirmDeletion()
        #expect(repository.deletedIDs == ["a"])
        #expect(viewModel.pendingDeletion == nil)
        #expect(viewModel.entries.map(\.id).sorted() == ["b", "c"])
    }

    @Test func confirmingWithNothingPendingDeletesNothing() {
        let (viewModel, repository) = makeViewModel(library)

        viewModel.confirmDeletion()

        #expect(repository.deletedIDs.isEmpty)
        #expect(viewModel.entries.count == 3)
    }

    @Test func emptyingTheLibraryClearsHiddenFiltersBeforeTheNextBookIsAdded() throws {
        let (viewModel, repository) = makeViewModel(library)
        viewModel.searchText = "Anathem"
        viewModel.statusFilter = .finished
        viewModel.sort = .title

        try repository.deleteAll()
        viewModel.load()

        #expect(viewModel.isEmpty)
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.statusFilter == nil)
        #expect(viewModel.sort == .title)

        try repository.add(makeEntry(id: "new", title: "A new beginning", readingStatus: .toRead))
        viewModel.load()
        #expect(viewModel.sections.flatMap(\.entries).map(\.id) == ["new"])
        #expect(!viewModel.hasNoMatches)
    }

    // MARK: - Hatalar

    @Test func aFailedLoadSurfacesAsAUserFacingError() {
        let repository = LibraryRepositoryMock()
        repository.errorToThrow = LocalLibraryRepositoryError.entryNotFound("x")
        let viewModel = BooksViewModel(libraryRepository: repository)

        viewModel.load()

        #expect(viewModel.error == .notInLibrary)
        #expect(viewModel.isEmpty)
        #expect(viewModel.sections.isEmpty)
    }
}

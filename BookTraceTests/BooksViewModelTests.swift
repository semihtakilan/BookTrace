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
            .status(.toRead), .status(.reading), .status(.finished)
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

    @Test func emptyGroupsAreLeftOut() {
        let (viewModel, _) = makeViewModel([library[0]])
        viewModel.grouping = .ownership

        #expect(viewModel.sections.map(\.kind) == [.ownership(.owned)])
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
        #expect(viewModel.sections.flatMap { $0.entries.map(\.id) } == ["a"])
    }

    @Test func aSearchThatMatchesNothingIsNotAnEmptyLibrary() {
        let (viewModel, _) = makeViewModel(library)

        viewModel.searchText = "zzz"

        #expect(viewModel.sections.isEmpty)
        #expect(viewModel.hasNoMatches)
        #expect(!viewModel.isEmpty)
    }

    @Test func nowReadingStepsAsideWhileSearching() {
        let (viewModel, _) = makeViewModel(library)
        #expect(viewModel.isShowingNowReading)
        #expect(viewModel.nowReading.map(\.id) == ["a"])

        viewModel.searchText = "dune"
        #expect(!viewModel.isShowingNowReading)
    }

    // MARK: - Sıralama

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

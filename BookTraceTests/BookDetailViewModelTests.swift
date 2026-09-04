//
//  BookDetailViewModelTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation
import Models
import Testing
@testable import BookTrace

@MainActor
struct BookDetailViewModelTests {

    @Test(arguments: ["", "380"])
    func addingAFinishedBookPersistsItsLastPage(pageCountText: String) throws {
        let (viewModel, repository) = makeViewModel()
        viewModel.load()
        viewModel.presentForm()
        viewModel.readingStatus = .finished
        viewModel.pageCountText = pageCountText
        viewModel.save()

        let entry = try #require(repository.storedEntries.first)
        #expect(entry.readingStatus == .finished)
        #expect(entry.currentPage == (Int(pageCountText) ?? 412))
        #expect(entry.progressPercentage == 100)
        #expect(entry.readingSessions.isEmpty)
        #expect(viewModel.didSave)
    }

    @Test func markingAnExistingBookFinishedKeepsItsActualSessions() throws {
        let entry = makeEntry(readingStatus: .reading, pageCount: 412, currentPage: 120,
                              sessions: [ReadingSession(startDate: Date(), durationSeconds: 600, pagesRead: 20)])
        let (viewModel, repository) = makeViewModel(stored: [entry])
        viewModel.load()
        viewModel.presentForm()
        viewModel.readingStatus = .finished
        viewModel.save()
        let stored = try #require(repository.storedEntries.first)
        #expect(stored.readingStatus == .finished)
        #expect(stored.currentPage == 412)
        #expect(stored.readingSessions == entry.readingSessions)
    }

    @Test func finishingWithoutKnownPagesDoesNotMakeUpALength() {
        let (viewModel, _) = makeViewModel(book: makeBook(pageCount: nil))
        viewModel.load()
        viewModel.presentForm()
        viewModel.readingStatus = .finished
        viewModel.save()
        #expect(viewModel.existingEntry?.readingStatus == .finished)
        #expect(viewModel.existingEntry?.effectivePageCount == nil)
    }

    private func makeViewModel(
        book: BookReference = makeBook(pageCount: 412, subjects: ["Fiction", "Adventure"]),
        stored: [LibraryEntry] = [],
        categories: [Models.Category] = [],
        detail: BookDetailFetchingMock = BookDetailFetchingMock()
    ) -> (BookDetailViewModel, LibraryRepositoryMock) {
        let repository = LibraryRepositoryMock()
        repository.storedEntries = stored
        repository.storedCategories = categories
        let settings = AppSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let viewModel = BookDetailViewModel(
            book: book,
            libraryRepository: repository,
            bookDetailFetching: detail,
            settings: settings
        )
        return (viewModel, repository)
    }

    /// Liste kaydında açıklama yok; ekran açıldığında tamamlanmalı.
    @Test func theBookIsEnrichedWhenItArrivesWithoutADescription() async {
        let detail = BookDetailFetchingMock(description: "A desert planet.")
        let (viewModel, _) = makeViewModel(book: makeBook(), detail: detail)

        viewModel.load()
        await viewModel.enrich()

        #expect(viewModel.book.description == "A desert planet.")
        #expect(await detail.callCount == 1)
    }

    /// Kütüphanedeki kitabın metadata'sı zaten saklandı: ağa çıkmanın karşılığı yok.
    @Test func aBookAlreadyInTheLibraryIsNotEnriched() async {
        let detail = BookDetailFetchingMock(description: "A desert planet.")
        let book = makeBook()
        let (viewModel, _) = makeViewModel(book: book, stored: [LibraryEntry(book: book)], detail: detail)

        viewModel.load()
        await viewModel.enrich()

        #expect(await detail.callCount == 0)
    }

    @Test func aBookThatAlreadyHasADescriptionIsLeftAlone() async {
        let detail = BookDetailFetchingMock(description: "Replaced.")
        let (viewModel, _) = makeViewModel(book: makeBook(description: "Already here."), detail: detail)

        viewModel.load()
        await viewModel.enrich()

        #expect(viewModel.book.description == "Already here.")
        #expect(await detail.callCount == 0)
    }

    /// B6: kaynağın verdiği sayfa sayısı forma yazılmamalı. Yazılsaydı kullanıcı
    /// hiçbir şey girmeden kaydettiğinde o değer kullanıcı girdisi olarak
    /// saklanır ve "kaynaktan gelen" / "kullanıcının girdiği" ayrımı kaybolurdu.
    @Test func theSourcePageCountIsOfferedAsAHintNotAsInput() {
        let (viewModel, _) = makeViewModel()

        viewModel.load()
        viewModel.presentForm()

        #expect(viewModel.pageCountText.isEmpty)
        #expect(viewModel.pageCountPlaceholder == "412")

        viewModel.save()

        #expect(viewModel.existingEntry?.pageCount == nil)
        // Kaynağın değeri hâlâ ilerleme hesabını besliyor.
        #expect(viewModel.existingEntry?.effectivePageCount == 412)
    }

    @Test func editingAnExistingBookShowsOnlyWhatTheUserTyped() {
        let entry = LibraryEntry(book: makeBook(pageCount: 412), pageCount: 500)
        let (viewModel, _) = makeViewModel(stored: [entry])

        viewModel.load()
        viewModel.presentForm()

        #expect(viewModel.pageCountText == "500")
    }

    @Test func aTypedPageCountOverridesTheSource() {
        let (viewModel, _) = makeViewModel()
        viewModel.load()
        viewModel.presentForm()

        viewModel.pageCountText = "380"
        viewModel.save()

        #expect(viewModel.existingEntry?.pageCount == 380)
        #expect(viewModel.existingEntry?.effectivePageCount == 380)
    }

    @Test func savingKeepsProgressAndSessionsThatAlreadyExist() throws {
        let entry = makeEntry(
            readingStatus: .reading, pageCount: 412, currentPage: 120,
            sessions: [ReadingSession(startDate: Date(), durationSeconds: 600, pagesRead: 20)]
        )
        let (viewModel, repository) = makeViewModel(stored: [entry])

        viewModel.load()
        viewModel.presentForm()
        viewModel.ownershipStatus = .owned
        viewModel.save()

        let stored = try #require(repository.storedEntries.first)
        #expect(stored.ownershipStatus == .owned)
        #expect(stored.currentPage == 120)
        #expect(stored.readingSessions.count == 1)
    }

    /// C3: etiket önerisi için tüm kütüphaneyi materyalize etmeye gerek yok.
    @Test func tagSuggestionsComeFromTheCategoryTable() {
        let (viewModel, _) = makeViewModel(categories: [Models.Category(name: "Book Club")])

        viewModel.load()

        let names = viewModel.suggestedCategories.map(\.name)
        #expect(names.contains("Book Club"))
        // Kitabın kendi konuları ve hazır öneriler de listede.
        #expect(names.contains("Fiction"))
        #expect(names.contains("Favorites"))
        // Aynı etiket iki kez görünmez.
        #expect(Set(names).count == names.count)
    }

    @Test func togglingATagSelectsAndDeselectsIt() {
        let (viewModel, _) = makeViewModel()
        let work = Models.Category(name: "Work")

        #expect(!viewModel.isSelected(work))
        viewModel.toggle(work)
        #expect(viewModel.isSelected(work))
        viewModel.toggle(work)
        #expect(!viewModel.isSelected(work))
    }

    @Test func aTypedTagIsAddedOnceAndTheFieldIsCleared() {
        let (viewModel, _) = makeViewModel()

        viewModel.newCategoryName = "  Reread  "
        viewModel.addTypedCategory()

        #expect(viewModel.selectedCategories.map(\.name) == ["Reread"])
        #expect(viewModel.newCategoryName.isEmpty)

        viewModel.newCategoryName = "reread"
        viewModel.addTypedCategory()
        #expect(viewModel.selectedCategories.count == 1)
    }

    @Test func onlyANonNumericPageCountBlocksSaving() {
        let (viewModel, _) = makeViewModel()

        viewModel.pageCountText = ""
        #expect(viewModel.canSave)

        viewModel.pageCountText = "300"
        #expect(viewModel.canSave)

        viewModel.pageCountText = "three hundred"
        #expect(!viewModel.canSave)

        viewModel.pageCountText = "-20"
        #expect(!viewModel.canSave)
        viewModel.pageCountText = "0"
        #expect(!viewModel.canSave)
        viewModel.pageCountText = "  "
        #expect(viewModel.canSave)
    }
}

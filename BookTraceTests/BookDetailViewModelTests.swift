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

    private func makeViewModel(
        book: BookReference = makeBook(pageCount: 412, subjects: ["Fiction", "Adventure"]),
        stored: [LibraryEntry] = [],
        categories: [Models.Category] = []
    ) -> (BookDetailViewModel, LibraryRepositoryMock) {
        let repository = LibraryRepositoryMock()
        repository.storedEntries = stored
        repository.storedCategories = categories
        let settings = AppSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        return (BookDetailViewModel(book: book, libraryRepository: repository, settings: settings), repository)
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
    }
}

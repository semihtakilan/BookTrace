//
//  ReadingSessionViewModelTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation
import Models
import Testing
@testable import BookTrace

@MainActor
struct ReadingSessionViewModelTests {

    private func makeViewModel(
        entry: LibraryEntry = makeEntry(pageCount: 300, currentPage: 40)
    ) -> (ReadingSessionViewModel, LibraryRepositoryMock) {
        let repository = LibraryRepositoryMock()
        repository.storedEntries = [entry]
        return (ReadingSessionViewModel(entry: entry, libraryRepository: repository), repository)
    }

    @Test func onlyWholeNumbersCountAsPages() {
        let (viewModel, _) = makeViewModel()

        viewModel.pagesReadText = "12"
        #expect(viewModel.pagesReadValue == 12)

        viewModel.pagesReadText = "  7 "
        #expect(viewModel.pagesReadValue == 7)

        viewModel.pagesReadText = ""
        #expect(viewModel.pagesReadValue == nil)

        viewModel.pagesReadText = "abc"
        #expect(viewModel.pagesReadValue == nil)
    }

    @Test func savingIsBlockedUntilThereIsBothTimeAndAPageCount() {
        let (viewModel, _) = makeViewModel()

        #expect(!viewModel.canSave)

        viewModel.pagesReadText = "10"
        // Sayaç hiç işlemedi; kaydedilecek bir süre yok.
        #expect(!viewModel.canSave)
    }

    @Test func theProjectedPagePreviewsProgressWithoutChangingTheBook() {
        let (viewModel, _) = makeViewModel()

        viewModel.pagesReadText = "35"

        #expect(viewModel.projectedPage == 75)
        #expect(viewModel.entry.currentPage == 40)
    }

    @Test func theProjectedPageStopsAtTheEndOfTheBook() {
        let (viewModel, _) = makeViewModel(entry: makeEntry(pageCount: 100, currentPage: 90))

        viewModel.pagesReadText = "50"

        #expect(viewModel.projectedPage == 100)
    }

    @Test func savingRecordsTheSessionAndMovesTheBookForward() throws {
        let (viewModel, repository) = makeViewModel()
        viewModel.pagesReadText = "30"

        viewModel.save()

        #expect(viewModel.didSave)
        #expect(!viewModel.isFinishing)
        #expect(viewModel.error == nil)

        let stored = try #require(repository.storedEntries.first)
        #expect(stored.currentPage == 70)
        #expect(stored.readingSessions.count == 1)
        #expect(stored.readingSessions[0].pagesRead == 30)
        #expect(stored.readingStatus == .reading)
    }

    @Test func savingWithoutAPageCountDoesNothing() {
        let (viewModel, repository) = makeViewModel()
        viewModel.pagesReadText = ""

        viewModel.save()

        #expect(!viewModel.didSave)
        #expect(repository.storedEntries[0].readingSessions.isEmpty)
    }

    @Test func aFailedSaveIsReportedAndTheScreenStaysOpen() {
        let (viewModel, repository) = makeViewModel()
        repository.errorToThrow = LocalLibraryRepositoryError.entryNotFound("book-1")
        viewModel.isFinishing = true
        viewModel.pagesReadText = "10"

        viewModel.save()

        #expect(!viewModel.didSave)
        #expect(viewModel.isFinishing)
        #expect(viewModel.error == .notInLibrary)
    }

    @Test func pausingAndResumingFlipsTheRunningState() {
        let (viewModel, _) = makeViewModel()
        viewModel.start()
        #expect(viewModel.isRunning)

        viewModel.togglePause()
        #expect(!viewModel.isRunning)

        viewModel.togglePause()
        #expect(viewModel.isRunning)
    }

    @Test func leavingTheFinishScreenWithoutSavingResumesTheTimer() {
        let (viewModel, _) = makeViewModel()
        viewModel.start()

        viewModel.beginFinishing()
        #expect(!viewModel.isRunning)
        #expect(viewModel.isFinishing)
        #expect(viewModel.pagesReadText.isEmpty)

        viewModel.isFinishing = false
        viewModel.resumeAfterFinishing()
        #expect(viewModel.isRunning)
    }

    @Test func theTimerStaysStoppedOnceTheSessionIsSaved() {
        let (viewModel, _) = makeViewModel()
        viewModel.start()
        viewModel.beginFinishing()
        viewModel.pagesReadText = "5"
        viewModel.save()

        viewModel.resumeAfterFinishing()

        #expect(!viewModel.isRunning)
    }
}

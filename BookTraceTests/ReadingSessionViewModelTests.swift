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

    @Test func aSavedSessionWaitsForItsCelebrationBeforeTheScreenCloses() {
        let (viewModel, _) = makeViewModel()
        viewModel.start()
        viewModel.pagesReadText = "30"

        viewModel.save()

        // Kayıt tamam ama ekran hemen kapanmıyor: kutlanacak bir şey var.
        #expect(viewModel.didSave)
        #expect(viewModel.outcome == .firstSession)
        #expect(!viewModel.isReadyToDismiss)

        viewModel.acknowledgeOutcome()
        #expect(viewModel.isReadyToDismiss)
    }

    @Test func aSessionWithNothingToCelebrateClosesStraightAway() {
        // Kitabın yarısı zaten okunmuş ve bu ilk oturum değil: eşik geçilmiyor.
        let entry = makeEntry(pageCount: 100, currentPage: 60, sessions: [
            ReadingSession(id: "s0", startDate: Date(), durationSeconds: 600, pagesRead: 60)
        ])
        let (viewModel, _) = makeViewModel(entry: entry)
        viewModel.start()
        viewModel.pagesReadText = "5"

        viewModel.save()

        #expect(viewModel.outcome == nil)
        #expect(viewModel.isReadyToDismiss)
    }

    @Test func eachElapsedThresholdIsAnnouncedOnce() {
        #expect(ReadingSessionViewModel.milestone(atElapsed: 4 * 60, after: 0) == nil)
        #expect(ReadingSessionViewModel.milestone(atElapsed: 5 * 60, after: 0) == 5)
        // Beşinci dakika duyurulduktan sonra altıncı dakika bir olay değil.
        #expect(ReadingSessionViewModel.milestone(atElapsed: 6 * 60, after: 5) == nil)
        #expect(ReadingSessionViewModel.milestone(atElapsed: 10 * 60, after: 5) == 10)
    }

    @Test func aLongBackgroundGapAnnouncesOnlyTheHighestThreshold() {
        // Uygulama arka planda kalıp geri döndüğünde sayaç sıçrıyor; aradaki
        // bütün eşikler için üst üste bildirim göstermek anlamsız.
        #expect(ReadingSessionViewModel.milestone(atElapsed: 47 * 60, after: 0) == 45)
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

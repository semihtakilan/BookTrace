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
        entry: LibraryEntry = makeEntry(pageCount: 300, currentPage: 40),
        clock: SessionTestClock = SessionTestClock()
    ) -> (ReadingSessionViewModel, LibraryRepositoryMock) {
        let repository = LibraryRepositoryMock()
        repository.storedEntries = [entry]
        return (ReadingSessionViewModel(entry: entry, libraryRepository: repository, now: { clock.date }), repository)
    }

    @Test func onlyWholeNumbersCountAsPages() {
        let (viewModel, _) = makeViewModel()

        viewModel.pagesReadText = "12"
        #expect(viewModel.pagesReadValue == 12)

        viewModel.pagesReadText = "  7 "
        #expect(viewModel.pagesReadValue == 7)

        viewModel.pagesReadText = "١٢"
        #expect(viewModel.pagesReadValue == 12)

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
        let clock = SessionTestClock()
        let (viewModel, repository) = makeViewModel(clock: clock)
        viewModel.start()
        clock.advance(seconds: 120)
        viewModel.tick()
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
        let clock = SessionTestClock()
        let (viewModel, repository) = makeViewModel(clock: clock)
        viewModel.start()
        clock.advance(seconds: 120)
        viewModel.tick()
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
        let clock = SessionTestClock()
        let (viewModel, _) = makeViewModel(clock: clock)
        viewModel.start()
        clock.advance(seconds: 120)
        viewModel.tick()
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
        let clock = SessionTestClock()
        let (viewModel, _) = makeViewModel(entry: entry, clock: clock)
        viewModel.start()
        clock.advance(seconds: 120)
        viewModel.tick()
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
        let clock = SessionTestClock()
        let (viewModel, _) = makeViewModel(clock: clock)
        viewModel.start()
        clock.advance(seconds: 120)
        viewModel.tick()
        viewModel.beginFinishing()
        viewModel.pagesReadText = "5"
        viewModel.save()

        viewModel.resumeAfterFinishing()

        #expect(!viewModel.isRunning)
    }
    @Test func backgroundTimeIsCountedButPausedTimeIsExcluded() {
        let clock = SessionTestClock()
        let (viewModel, _) = makeViewModel(clock: clock)
        viewModel.start()
        clock.advance(seconds: 75)
        viewModel.tick()
        #expect(viewModel.elapsedSeconds == 75)

        viewModel.togglePause()
        clock.advance(seconds: 300)
        viewModel.tick()
        #expect(viewModel.elapsedSeconds == 75)

        viewModel.togglePause()
        clock.advance(seconds: 25)
        viewModel.beginFinishing()
        #expect(viewModel.elapsedSeconds == 100)
    }

    @Test func returningFromFinishPreservesAManualPauseAndPageInput() {
        let clock = SessionTestClock()
        let (viewModel, _) = makeViewModel(clock: clock)
        viewModel.start()
        clock.advance(seconds: 30)
        viewModel.togglePause()
        viewModel.pagesReadText = "7"
        viewModel.beginFinishing()
        viewModel.isFinishing = false
        viewModel.resumeAfterFinishing()
        #expect(!viewModel.isRunning)
        #expect(viewModel.pagesReadText == "7")
    }

    @Test func saveEnforcesValidationEvenWhenCalledDirectly() {
        let clock = SessionTestClock()
        let (viewModel, repository) = makeViewModel(clock: clock)
        viewModel.pagesReadText = "5"
        viewModel.save()
        #expect(repository.storedEntries[0].readingSessions.isEmpty)

        viewModel.start()
        clock.advance(seconds: 60)
        for invalid in ["-1", "261", String(Int.max), "hello"] {
            viewModel.pagesReadText = invalid
            viewModel.save()
            #expect(repository.storedEntries[0].readingSessions.isEmpty)
        }
        #expect(!viewModel.didSave)
    }

    @Test func duplicateSaveCannotRecordTimeOrPagesTwice() throws {
        let clock = SessionTestClock()
        let (viewModel, repository) = makeViewModel(clock: clock)
        viewModel.start()
        clock.advance(seconds: 120)
        viewModel.pagesReadText = "5"
        viewModel.save()
        clock.advance(seconds: 60)
        viewModel.save()
        viewModel.start()
        viewModel.togglePause()
        let stored = try #require(repository.storedEntries.first)
        #expect(stored.readingSessions.count == 1)
        #expect(stored.readingSessions[0].durationSeconds == 120)
        #expect(stored.currentPage == 45)
        #expect(!viewModel.isRunning)
    }

    @Test func discardingFromFinishEndsTheEntireSessionWithoutWriting() {
        let clock = SessionTestClock()
        let (viewModel, repository) = makeViewModel(clock: clock)
        viewModel.start()
        clock.advance(seconds: 60)
        viewModel.beginFinishing()
        viewModel.pagesReadText = "5"
        viewModel.discard()
        viewModel.resumeAfterFinishing()
        viewModel.save()
        #expect(viewModel.isReadyToDismiss)
        #expect(!viewModel.isFinishing)
        #expect(!viewModel.isRunning)
        #expect(repository.storedEntries[0].readingSessions.isEmpty)
    }

    @Test func aTimeOnlySessionRemainsSaveable() {
        let clock = SessionTestClock()
        let (viewModel, repository) = makeViewModel(clock: clock)
        viewModel.start()
        clock.advance(seconds: 60)
        viewModel.beginFinishing()
        viewModel.pagesReadText = "0"
        viewModel.save()
        #expect(viewModel.didSave)
        #expect(repository.storedEntries[0].readingSessions[0].pagesRead == 0)
        #expect(repository.storedEntries[0].currentPage == 40)
    }

    @Test func reappearingDoesNotRestartAPausedZeroSecondSession() {
        let (viewModel, _) = makeViewModel()
        viewModel.start()
        viewModel.togglePause()
        viewModel.start()
        #expect(!viewModel.isRunning)
    }

}


@MainActor
private final class SessionTestClock {
    var date = Date(timeIntervalSince1970: 1_700_000_000)

    func advance(seconds: TimeInterval) {
        date = date.addingTimeInterval(seconds)
    }
}

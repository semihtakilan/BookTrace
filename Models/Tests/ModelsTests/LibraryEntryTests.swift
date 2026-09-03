//
//  LibraryEntryTests.swift
//  ModelsTests
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Foundation
import Testing
@testable import Models

struct LibraryEntryTests {

    @Test func aFinishedEntryStartsAtItsKnownLastPageWithoutInventingSessions() {
        let entry = LibraryEntry(book: makeReference(id: "finished", pageCount: 300), readingStatus: .finished)
        #expect(entry.currentPage == 300)
        #expect(entry.progressPercentage == 100)
        #expect(entry.readingSessions.isEmpty)
        #expect(entry.totalReadSeconds == 0)
    }

    @Test func finishingUsesTheReadersEditionLength() {
        var entry = LibraryEntry(book: makeReference(id: "finished", pageCount: 300), pageCount: 280)
        entry.setReadingStatus(.finished)
        #expect(entry.currentPage == 280)
        entry.setPageCount(320)
        #expect(entry.currentPage == 320)
        #expect(entry.readingStatus == .finished)
    }

    @Test func anUnknownLengthCanBeFinishedAndCompletedWhenItsLengthIsAdded() {
        var entry = LibraryEntry(book: makeReference(id: "unknown"))
        entry.setReadingStatus(.finished)
        #expect(entry.currentPage == 0)
        #expect(entry.progressFraction == nil)
        #expect(entry.readingStatus == .finished)
        entry.setPageCount(180)
        #expect(entry.currentPage == 180)
        #expect(entry.progressPercentage == 100)
        #expect(entry.readingStatus == .finished)
    }

    @Test func aNewEntryStartsWithSafeDefaults() {
        let entry = LibraryEntry(book: makeReference(id: "book-1", title: "Domain Driven Design"))

        #expect(entry.id == "book-1")
        #expect(entry.readingStatus == .toRead)
        #expect(entry.ownershipStatus == .notOwned)
        #expect(entry.progressType == .pages)
        #expect(entry.currentPage == 0)
        #expect(entry.readingSessions.isEmpty)
    }

    @Test func aUserSuppliedPageCountOverridesTheOneFromTheSource() {
        var entry = LibraryEntry(book: makeReference(id: "book-1", pageCount: 300))
        #expect(entry.effectivePageCount == 300)

        entry.pageCount = 250
        #expect(entry.effectivePageCount == 250)
    }

    @Test func progressIsUnknownWithoutAPageCount() {
        let entry = LibraryEntry(book: makeReference(id: "book-1"), currentPage: 40)

        #expect(entry.effectivePageCount == nil)
        #expect(entry.progressFraction == nil)
        #expect(entry.remainingPages == nil)
        #expect(entry.estimatedRemainingSeconds == nil)
    }

    @Test func progressIsReportedAsAFractionAndAPercentage() {
        let entry = LibraryEntry(book: makeReference(id: "book-1", pageCount: 200), currentPage: 50)

        #expect(entry.progressFraction == 0.25)
        #expect(entry.progressPercentage == 25)
        #expect(entry.remainingPages == 150)
    }

    @Test func advancingProgressMovesAWaitingBookIntoReading() {
        var entry = LibraryEntry(book: makeReference(id: "book-1", pageCount: 200))

        entry.advanceProgress(by: 20)

        #expect(entry.currentPage == 20)
        #expect(entry.readingStatus == .reading)
    }

    @Test func progressNeverExceedsThePageCountAndFinishesTheBook() {
        var entry = LibraryEntry(
            book: makeReference(id: "book-1", pageCount: 200),
            readingStatus: .reading,
            currentPage: 190
        )

        entry.advanceProgress(by: 50)

        #expect(entry.currentPage == 200)
        #expect(entry.progressFraction == 1.0)
        #expect(entry.readingStatus == .finished)
    }

    @Test func applyingASessionRecordsItAndAdvancesTheProgress() {
        var entry = LibraryEntry(
            book: makeReference(id: "book-1", pageCount: 300),
            readingStatus: .reading
        )

        entry.apply(ReadingSession(startDate: Date(), durationSeconds: 1_800, pagesRead: 30))

        #expect(entry.readingSessions.count == 1)
        #expect(entry.currentPage == 30)
        #expect(entry.totalPagesRead == 30)
        #expect(entry.totalReadSeconds == 1_800)
    }

    @Test func aSessionCannotRecordMorePagesThanTheBookHasLeft() {
        var entry = LibraryEntry(
            book: makeReference(id: "book-1", pageCount: 716),
            readingStatus: .reading,
            currentPage: 700
        )

        entry.apply(ReadingSession(startDate: Date(), durationSeconds: 600, pagesRead: 99_999))

        // Kaydedilen oturum da kırpılmalı: `pagesRead` okuma hızının paydası.
        #expect(entry.readingSessions.first?.pagesRead == 16)
        #expect(entry.currentPage == 716)
        #expect(entry.totalPagesRead == 16)
        #expect(entry.secondsPerPage == 600.0 / 16.0)
    }

    @Test func loweringThePageCountPullsProgressDownWithIt() {
        var entry = LibraryEntry(
            book: makeReference(id: "book-1", pageCount: 716),
            readingStatus: .reading,
            currentPage: 716
        )

        entry.setPageCount(100)

        #expect(entry.currentPage == 100)
        #expect(entry.progressFraction == 1.0)
    }

    @Test func rollingProgressBackMeansTheBookIsNoLongerFinished() {
        var entry = LibraryEntry(
            book: makeReference(id: "book-1", pageCount: 200),
            readingStatus: .finished,
            currentPage: 200
        )

        entry.setProgress(currentPage: 100)

        #expect(entry.readingStatus == .reading)
    }

    @Test func movingProgressToTheLastPageFinishesTheBook() {
        var entry = LibraryEntry(
            book: makeReference(id: "book-1", pageCount: 200),
            readingStatus: .reading,
            currentPage: 10
        )

        entry.setProgress(currentPage: 200)

        #expect(entry.readingStatus == .finished)
    }

    @Test func anAbandonedBookStaysAbandonedWhileProgressIsPartial() {
        var entry = LibraryEntry(
            book: makeReference(id: "book-1", pageCount: 200),
            readingStatus: .abandoned,
            currentPage: 40
        )

        entry.setProgress(currentPage: 60)

        #expect(entry.readingStatus == .abandoned)
    }

    @Test func negativeValuesAreClampedAway() {
        let session = ReadingSession(startDate: Date(), durationSeconds: -10, pagesRead: -5)
        var entry = LibraryEntry(book: makeReference(id: "book-1", pageCount: 100), currentPage: -3)

        #expect(session.durationSeconds == 0)
        #expect(session.pagesRead == 0)
        #expect(entry.currentPage == 0)

        entry.advanceProgress(by: -20)
        #expect(entry.currentPage == 0)
    }
}

struct ReadingSpeedEstimatorTests {

    @Test func theDefaultSpeedIsTwoMinutesPerPage() {
        #expect(ReadingSpeedEstimator.defaultSecondsPerPage == 120)
        #expect(ReadingSpeedEstimator.secondsPerPage(for: []) == 120)
        #expect(!ReadingSpeedEstimator.hasPersonalizedSpeed(for: []))
    }

    @Test func aSessionWithoutPagesFallsBackToTheDefaultSpeed() {
        let sessions = [ReadingSession(startDate: Date(), durationSeconds: 600, pagesRead: 0)]

        #expect(ReadingSpeedEstimator.secondsPerPage(for: sessions) == 120)
        #expect(!ReadingSpeedEstimator.hasPersonalizedSpeed(for: sessions))
    }

    @Test func theSpeedIsTheTotalTimeDividedByTheTotalPages() {
        let sessions = [
            ReadingSession(startDate: Date(), durationSeconds: 600, pagesRead: 10),
            ReadingSession(startDate: Date(), durationSeconds: 900, pagesRead: 20)
        ]

        // 1500 saniye / 30 sayfa = 50 saniye
        #expect(ReadingSpeedEstimator.secondsPerPage(for: sessions) == 50)
        #expect(ReadingSpeedEstimator.hasPersonalizedSpeed(for: sessions))
    }

    @Test func theRemainingEstimateUsesTheDefaultSpeedBeforeAnySession() {
        let entry = LibraryEntry(book: makeReference(id: "book-1", pageCount: 100), currentPage: 90)

        #expect(entry.estimatedRemainingSeconds == 1_200.0)
        #expect(!entry.hasPersonalizedSpeed)
    }

    @Test func theRemainingEstimateAdaptsOnceSessionsExist() {
        var entry = LibraryEntry(
            book: makeReference(id: "book-1", pageCount: 100),
            readingStatus: .reading
        )

        entry.apply(ReadingSession(startDate: Date(), durationSeconds: 600, pagesRead: 20))

        // 30 saniye/sayfa × kalan 80 sayfa
        #expect(entry.secondsPerPage == 30.0)
        #expect(entry.estimatedRemainingSeconds == 2_400.0)
        #expect(entry.hasPersonalizedSpeed)
    }

    @Test func aFinishedBookHasNoRemainingEstimate() {
        let entry = LibraryEntry(
            book: makeReference(id: "book-1", pageCount: 100),
            readingStatus: .finished,
            currentPage: 100
        )

        #expect(entry.estimatedRemainingSeconds == nil)
    }
}

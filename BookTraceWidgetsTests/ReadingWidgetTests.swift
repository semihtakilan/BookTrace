//
//  ReadingWidgetTests.swift
//  BookTraceWidgetsTests
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import BookTraceShared
import Foundation
import Models
import Testing

struct ReadingWidgetTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func runningTimerIncludesBackgroundTimeAndPreviousActiveSegments() {
        let clock = ReadingActivityClock(accumulatedSeconds: 75, runningSince: now, now: now)
        #expect(clock.elapsed(at: now.addingTimeInterval(25)) == 100)
        #expect(clock.startDate == now.addingTimeInterval(-75))
    }

    @Test func pausedTimerStaysFrozenAcrossLongBackgroundGaps() {
        let clock = ReadingActivityClock(accumulatedSeconds: 75, runningSince: nil, now: now)
        #expect(clock.isPaused)
        #expect(clock.elapsed(at: now.addingTimeInterval(3_600)) == 75)
    }

    @Test func resumeExcludesTimeSpentPaused() {
        let resumedAt = now.addingTimeInterval(600)
        let resumed = ReadingActivityClock(accumulatedSeconds: 120, runningSince: resumedAt, now: resumedAt)
        #expect(resumed.elapsed(at: resumedAt.addingTimeInterval(30)) == 150)
        #expect(!resumed.isPaused)
    }

    @Test func clockCannotShowNegativeDurationAfterAClockChange() {
        let clock = ReadingActivityClock(accumulatedSeconds: 0, runningSince: now, now: now)
        #expect(clock.elapsed(at: now.addingTimeInterval(-60)) == 0)
    }

    @Test func subscriptionExpiryLocksWidgetWhileLifetimeRemainsAvailable() {
        #expect(!BookTraceSharedConfiguration.hasWidgetAccess(enabled: false, expiration: nil, now: now))
        #expect(BookTraceSharedConfiguration.hasWidgetAccess(enabled: true, expiration: nil, now: now))
        #expect(BookTraceSharedConfiguration.hasWidgetAccess(enabled: true, expiration: now.addingTimeInterval(1), now: now))
        #expect(!BookTraceSharedConfiguration.hasWidgetAccess(enabled: true, expiration: now, now: now))
    }

    @Test func emptyLibraryProducesAnHonestEmptySnapshot() {
        let snapshot = ReadingWidgetSnapshot(entries: [], goals: [], now: now)
        #expect(snapshot.book == nil)
        #expect(snapshot.streak == 0)
        #expect(snapshot.recentActivity == Array(repeating: false, count: 7))
        #expect(snapshot.goal == nil)
        #expect(snapshot.goalFraction == 0)
    }

    @Test func nowReadingUsesMostRecentlyReadBookAndPersonalSpeed() {
        let recentSession = ReadingSession(startDate: now.addingTimeInterval(-60), durationSeconds: 600, pagesRead: 10)
        let old = LibraryEntry(book: BookReference(id: "old", title: "Old"), readingStatus: .reading, addedDate: now.addingTimeInterval(-600))
        let recent = LibraryEntry(book: BookReference(id: "recent", title: "Recent", pageCount: 100), readingStatus: .reading, currentPage: 40, addedDate: now.addingTimeInterval(-1_000), readingSessions: [recentSession])
        let finished = LibraryEntry(book: BookReference(id: "finished", title: "Finished"), readingStatus: .finished, addedDate: now)
        let snapshot = ReadingWidgetSnapshot(entries: [old, finished, recent], goals: [], now: now)
        #expect(snapshot.book?.id == "recent")
        #expect(snapshot.remainingMinutes == 60)
        #expect(snapshot.streak == 1)
    }

    @Test func yearlyGoalIsPreferredAndDuplicateSessionsDoNotInflateProgress() {
        let session = ReadingSession(id: "shared", startDate: now.addingTimeInterval(-60), durationSeconds: 600, pagesRead: 10)
        let entry = LibraryEntry(book: BookReference(id: "book", title: "Book"), readingSessions: [session, session])
        let monthly = ReadingGoal(id: "monthly", period: .monthly, metric: .minutes, target: 100, startDate: now.addingTimeInterval(-600))
        let yearly = ReadingGoal(id: "yearly", period: .yearly, metric: .minutes, target: 200, startDate: now.addingTimeInterval(-600))
        let snapshot = ReadingWidgetSnapshot(entries: [entry], goals: [monthly, yearly], now: now)
        #expect(snapshot.goal?.id == "yearly")
        #expect(snapshot.goalValue == 10)
        #expect(snapshot.goalFraction == 0.05)
    }

    @Test func futureAndInactiveGoalsDoNotAppear() {
        let future = ReadingGoal(period: .yearly, metric: .books, target: 12, startDate: now.addingTimeInterval(60))
        let inactive = ReadingGoal(period: .monthly, metric: .books, target: 2, startDate: now.addingTimeInterval(-60), isActive: false)
        #expect(ReadingWidgetSnapshot(entries: [], goals: [future, inactive], now: now).goal == nil)
    }
}

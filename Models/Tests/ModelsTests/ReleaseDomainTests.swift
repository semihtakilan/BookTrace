//
//  ReleaseDomainTests.swift
//  ModelsTests
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation
import Testing
@testable import Models

struct ReleaseDomainTests {
    @Test func finishDatesFollowTransitionsAndDoNotChangeWhenReapplied() {
        var entry = LibraryEntry(book: BookReference(id: "one", title: "One", pageCount: 100))
        let first = date(2026, 1, 2)
        entry.setReadingStatus(.finished, at: first)
        #expect(entry.finishedDate == first)
        entry.setReadingStatus(.finished, at: date(2026, 1, 3))
        #expect(entry.finishedDate == first)
        entry.setProgress(currentPage: 20)
        #expect(entry.finishedDate == nil)
        #expect(entry.readingStatus == .reading)
        let second = date(2026, 1, 4)
        entry.setProgress(currentPage: 100, at: second)
        #expect(entry.finishedDate == second)
        entry.readingStatus = .abandoned
        #expect(entry.finishedDate == nil)
        entry.readingStatus = .finished
        #expect(entry.finishedDate != nil)
    }

    @Test func finishingWithAnImportedSessionUsesItsActualEnd() {
        var entry = LibraryEntry(book: BookReference(id: "one", title: "One", pageCount: 10))
        let session = ReadingSession(startDate: date(2024, 2, 3), durationSeconds: 600, pagesRead: 10)
        entry.apply(session)
        #expect(entry.finishedDate == session.endDate)
    }

    @Test func invalidRatingsAndPagesCannotSurviveMutationOrDecoding() throws {
        var entry = LibraryEntry(book: BookReference(id: "one", title: "One"), rating: 9)
        #expect(entry.rating == nil)
        entry.rating = 1
        #expect(entry.rating == 1)
        entry.rating = 0
        #expect(entry.rating == nil)
        entry.rating = 5
        #expect(entry.rating == 5)
        var quote = Quote(text: "Text", pageNumber: -2)
        #expect(quote.pageNumber == nil)
        quote.pageNumber = 4
        quote.pageNumber = 0
        #expect(quote.pageNumber == nil)
        let raw = try JSONEncoder().encode(entry)
        let invalid = String(decoding: raw, as: UTF8.self).replacingOccurrences(of: "\"rating\":5", with: "\"rating\":-1")
        #expect(try JSONDecoder().decode(LibraryEntry.self, from: Data(invalid.utf8)).rating == nil)
    }

    @Test func legacyFinishedRecordsKeepUnknownDatesAndDefaultNewFields() throws {
        let entry = LibraryEntry(book: BookReference(id: "one", title: "One"), readingStatus: .finished, addedDate: date(2020, 1, 1))
        let data = try JSONEncoder().encode(entry)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["rating", "finishedDate", "notes", "isFavorite", "quotes"] { json.removeValue(forKey: key) }
        let decoded = try JSONDecoder().decode(LibraryEntry.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.finishedDate == nil)
        #expect(decoded.quotes.isEmpty)
        #expect(!decoded.isFavorite)
        #expect(decoded.rating == nil)
    }

    @Test func completeBackupsPreserveSessionsQuotesGoalsAndSubsecondDates() throws {
        let session = ReadingSession(startDate: Date(timeIntervalSince1970: 12345678.125), durationSeconds: 901, pagesRead: 17)
        let quote = Quote(text: "Çağrı\n\"A quote\"", pageNumber: 12, note: "Personal note", isFavorite: true)
        let entry = LibraryEntry(book: BookReference(id: "one", title: "One"), readingStatus: .finished,
                                 readingSessions: [session], rating: 4, finishedDate: session.endDate,
                                 notes: "notes", isFavorite: true, quotes: [quote])
        let goal = ReadingGoal(period: .yearly, metric: .books, target: 20)
        let backup = try LibraryBackupCodec.decode(LibraryBackupCodec.encode(entries: [entry], goals: [goal]))
        #expect(backup.entries == [entry])
        #expect(backup.goals == [goal])
        #expect(backup.schemaVersion == 2)
    }

    @Test func backupRejectsNewerVersionsInsteadOfSilentlyDroppingData() throws {
        let data = try LibraryBackupCodec.encode(entries: [])
        let newer = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\"schemaVersion\" : 2", with: "\"schemaVersion\" : 99")
        #expect(throws: LibraryBackupCodec.BackupError.unsupportedVersion(99)) {
            try LibraryBackupCodec.decode(Data(newer.utf8))
        }
    }

    @Test func goalMinutesRoundAfterSummingAndDeduplicateSessions() {
        let now = date(2026, 3, 12, hour: 18)
        let sessions = [
            ReadingSession(id: "a", startDate: date(2026, 3, 12, hour: 8), durationSeconds: 35, pagesRead: 3),
            ReadingSession(id: "b", startDate: date(2026, 3, 12, hour: 9), durationSeconds: 35, pagesRead: 2)
        ]
        let entry = LibraryEntry(book: BookReference(id: "one", title: "One"), readingSessions: sessions + [sessions[0]])
        let goal = ReadingGoal(period: .daily, metric: .minutes, target: 1, startDate: date(2026, 3, 12))
        let progress = GoalProgressCalculator.progress(for: goal, entries: [entry, entry], now: now, calendar: utcCalendar)
        #expect(progress.value == 1)
        #expect(progress.isComplete)
        #expect(progress.fraction == 1)
    }

    @Test func recurringGoalsRespectStartOfPeriodCreationAndFutureDates() {
        let goal = ReadingGoal(period: .monthly, metric: .pages, target: 100, startDate: date(2026, 3, 2))
        let times = [date(2026, 2, 28), date(2026, 3, 1), date(2026, 3, 2), date(2026, 3, 12), date(2026, 4, 1)]
        let entry = LibraryEntry(book: BookReference(id: "one", title: "One"), readingSessions: times.map {
            ReadingSession(startDate: $0, durationSeconds: 100, pagesRead: 10)
        })
        #expect(GoalProgressCalculator.progress(for: goal, entries: [entry], now: date(2026, 3, 10), calendar: utcCalendar).value == 10)
        #expect(GoalProgressCalculator.progress(for: goal, entries: [entry], now: date(2026, 4, 1), calendar: utcCalendar).value == 10)
        var inactive = goal
        inactive.isActive = false
        #expect(GoalProgressCalculator.progress(for: inactive, entries: [entry], now: date(2026, 3, 10), calendar: utcCalendar).value == 0)
    }

    @Test func booksGoalsUseCompletionDateAndExcludeUnknownAndUnfinishedBooks() {
        let finish = date(2026, 3, 12)
        let complete = LibraryEntry(book: BookReference(id: "one", title: "One"), readingStatus: .finished, finishedDate: finish)
        let unknown = LibraryEntry(book: BookReference(id: "two", title: "Two"), readingStatus: .finished)
        let old = LibraryEntry(book: BookReference(id: "three", title: "Three"), readingStatus: .finished, finishedDate: date(2025, 1, 1))
        let goal = ReadingGoal(period: .yearly, metric: .books, target: 2, startDate: date(2026, 1, 1))
        let progress = GoalProgressCalculator.progress(for: goal, entries: [complete, complete, unknown, old], now: finish, calendar: utcCalendar)
        #expect(progress.value == 1)
        #expect(progress.fraction == 0.5)
    }

    @Test func dailyGoalsUseCalendarDaysAcrossDaylightSavingChanges() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8)))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 23)))
        let goal = ReadingGoal(period: .daily, metric: .sessions, target: 1, startDate: start)
        let progress = GoalProgressCalculator.progress(for: goal, entries: [], now: now, calendar: calendar)
        #expect(progress.interval.duration == 23 * 3600)
    }

    @Test func invalidGoalTargetsAreRepairedOnInitMutationAndDecode() throws {
        var goal = ReadingGoal(period: .weekly, metric: .pages, target: 0)
        #expect(goal.target == 1)
        goal.target = -5
        #expect(goal.target == 1)
        let data = try JSONEncoder().encode(goal)
        let invalid = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\"target\":1", with: "\"target\":0")
        #expect(try JSONDecoder().decode(ReadingGoal.self, from: Data(invalid.utf8)).target == 1)
    }

    @Test func yearlyStatisticsIncludeLeapDayAndExcludeNextYearBoundary() {
        let sessions = [
            ReadingSession(id: "a", startDate: date(2024, 2, 29, hour: 10), durationSeconds: 600, pagesRead: 10),
            ReadingSession(id: "b", startDate: date(2024, 12, 31, hour: 20), durationSeconds: 300, pagesRead: 5),
            ReadingSession(id: "c", startDate: date(2025, 1, 1), durationSeconds: 9999, pagesRead: 999)
        ]
        let entry = LibraryEntry(book: BookReference(id: "one", title: "One"), readingSessions: sessions + [sessions[0]])
        let stats = ReadingStatistics(entries: [entry], year: 2024, calendar: utcCalendar)
        #expect(stats.heatmap.count == 366)
        #expect(stats.monthly.count == 12)
        #expect(stats.totalSeconds == 900)
        #expect(stats.totalPages == 15)
        #expect(stats.totalSessions == 2)
        #expect(stats.hourly[10].sessions == 1)
        #expect(stats.hourly[20].seconds == 300)
        #expect(stats.monthly[1].pages == 10)
        #expect(stats.monthly[11].pages == 5)
        #expect(stats.pace.map(\.secondsPerPage) == [60, 60])
    }

    @Test func measuredPaceExcludesTimeOnlyAndUntimedPageEntries() {
        let entry = LibraryEntry(book: BookReference(id: "one", title: "One"), readingSessions: [
            ReadingSession(startDate: date(2026, 1, 1), durationSeconds: 600, pagesRead: 10),
            ReadingSession(startDate: date(2026, 1, 2), durationSeconds: 6000, pagesRead: 0),
            ReadingSession(startDate: date(2026, 1, 3), durationSeconds: 0, pagesRead: 400)
        ])
        let stats = ReadingStatistics(entries: [entry], year: 2026, calendar: utcCalendar)
        #expect(stats.pace.first?.secondsPerPage == 60)
        #expect(stats.totalSeconds == 6600)
    }

    @Test func annualSummaryUsesOnlyKnownFinishesAndDeterministicFavorites() {
        let first = LibraryEntry(book: BookReference(id: "a", title: "A", pageCount: 200, subjects: ["Fiction", " fiction "]),
                                 readingStatus: .finished, readingSessions: [
                                    ReadingSession(startDate: date(2026, 4, 1), durationSeconds: 600, pagesRead: 10),
                                    ReadingSession(startDate: date(2026, 4, 2), durationSeconds: 600, pagesRead: 10)
                                 ], rating: 5, finishedDate: date(2026, 4, 3))
        let favorite = LibraryEntry(book: BookReference(id: "b", title: "B", pageCount: 100, subjects: ["Fiction", "History"]),
                                    readingStatus: .finished, readingSessions: [
                                        ReadingSession(startDate: date(2026, 4, 3), durationSeconds: 600, pagesRead: 30)
                                    ], rating: 5, finishedDate: date(2026, 4, 4), isFavorite: true)
        let unknown = LibraryEntry(book: BookReference(id: "c", title: "C"), readingStatus: .finished)
        let stats = ReadingStatistics(entries: [first, favorite, unknown], year: 2026, calendar: utcCalendar)
        #expect(stats.completedBooks == 2)
        #expect(stats.ratings[4].count == 2)
        #expect(stats.genres.first?.name == "fiction")
        #expect(stats.genres.first?.count == 2)
        #expect(stats.averageFinishedBookPages == 150)
        #expect(stats.averageFinishedBookSeconds == 900)
        let summary = YearInReview(entries: [first, favorite, unknown], year: 2026, calendar: utcCalendar)
        #expect(summary.totalBooks == 2)
        #expect(summary.longestStreak == 3)
        #expect(summary.fastestBook?.id == "b")
        #expect(summary.bookOfYear?.id == "b")
        #expect(summary.topGenre == "fiction")
    }

    @Test func recommendationsUseFavoritesAuthorsAndNegativeAbandonedSignals() {
        let library = [
            LibraryEntry(book: BookReference(id: "read", title: "Read", authors: ["A Writer"], subjects: ["History"]), readingStatus: .finished, rating: 5),
            LibraryEntry(book: BookReference(id: "dnf", title: "Stopped", subjects: ["Horror"]), readingStatus: .abandoned),
            LibraryEntry(book: BookReference(id: "love", title: "Love", subjects: ["Science"]), isFavorite: true)
        ]
        let author = BookReference(id: "author", title: "Another", authors: ["a writer"])
        let history = BookReference(id: "history", title: "History", subjects: ["HISTORY"])
        let horror = BookReference(id: "horror", title: "Horror", subjects: ["Horror"])
        let science = BookReference(id: "science", title: "Science", subjects: ["Science"])
        let ranked = RecommendationEngine.recommend(candidates: [horror, history, author, science, library[0].book], library: library)
        #expect(ranked.map(\.id) == ["author", "history", "science"])
        #expect(RecommendationEngine.preferredSubjects(in: library) == ["history", "science"])
    }

    @Test func recommendationsExcludeExistingEditionsAndDuplicateCandidates() {
        let library = [LibraryEntry(book: BookReference(id: "read", title: "Read", isbn13: "9780306406157", subjects: ["Science"]), readingStatus: .finished)]
        let old = BookReference(id: "other-source", title: "Other", isbn13: "9780306406157", subjects: ["Science"])
        let new = BookReference(id: "new", title: "New", subjects: ["Science"])
        #expect(RecommendationEngine.recommend(candidates: [old, new, new], library: library).map(\.id) == ["new"])
        #expect(RecommendationEngine.recommend(candidates: [new], library: library, limit: 0).isEmpty)
        #expect(RecommendationEngine.recommend(candidates: [new], library: []).isEmpty)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}

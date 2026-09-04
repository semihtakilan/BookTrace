//
//  ReadingStreakTests.swift
//  ModelsTests
//
//  Created by Semih TAKILAN on 04.09.2026.
//

import Foundation
import Testing
@testable import Models

struct ReadingStreakTests {

    /// Takvim ve "şimdi" sabitleniyor; aksi hâlde testler gece yarısı ve yaz
    /// saati geçişlerinde kendiliğinden kırılıyor.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul") ?? .gmt
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 4, hour: 21))!
    }

    private func session(daysAgo: Int, hour: Int = 12) -> ReadingSession {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
        let start = calendar.date(byAdding: .hour, value: hour, to: day)!
        return ReadingSession(startDate: start, durationSeconds: 600, pagesRead: 5)
    }

    @Test func noSessionsMeansNoStreak() {
        #expect(ReadingStreak.current(from: [], now: now, calendar: calendar) == 0)
    }

    @Test func consecutiveDaysEndingTodayCount() {
        let sessions = [session(daysAgo: 0), session(daysAgo: 1), session(daysAgo: 2)]

        #expect(ReadingStreak.current(from: sessions, now: now, calendar: calendar) == 3)
    }

    @Test func todayIsStillOpenSoYesterdaysStreakSurvives() {
        // Gün bitmeden seri kırılmış sayılmıyor.
        let sessions = [session(daysAgo: 1), session(daysAgo: 2)]

        #expect(ReadingStreak.current(from: sessions, now: now, calendar: calendar) == 2)
    }

    @Test func aMissedDayEndsTheStreak() {
        let sessions = [session(daysAgo: 0), session(daysAgo: 2), session(daysAgo: 3)]

        #expect(ReadingStreak.current(from: sessions, now: now, calendar: calendar) == 1)
    }

    @Test func twoSessionsOnTheSameDayCountOnce() {
        let sessions = [session(daysAgo: 0, hour: 9), session(daysAgo: 0, hour: 22), session(daysAgo: 1)]

        #expect(ReadingStreak.current(from: sessions, now: now, calendar: calendar) == 2)
    }

    @Test func anOldStreakThatEndedBeforeYesterdayDoesNotCount() {
        let sessions = [session(daysAgo: 4), session(daysAgo: 5)]

        #expect(ReadingStreak.current(from: sessions, now: now, calendar: calendar) == 0)
    }

    @Test func recentActivityRunsFromOldestToToday() {
        let activity = ReadingStreak.recentActivity(
            from: [session(daysAgo: 0), session(daysAgo: 3)],
            days: 7, now: now, calendar: calendar
        )

        #expect(activity.count == 7)
        #expect(activity.last == true)
        #expect(activity[3] == true)
        #expect(activity[0] == false)
    }
}

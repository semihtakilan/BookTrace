//
//  ReadingWidgetSnapshot.swift
//  BookTraceShared
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation
import Models

/// Value-only projection shared by widgets and their hostless unit tests.
public struct ReadingWidgetSnapshot: Sendable {
    public let book: LibraryEntry?
    public let streak: Int
    public let recentActivity: [Bool]
    public let remainingMinutes: Int?
    public let goal: ReadingGoal?
    public let goalValue: Int
    public let goalFraction: Double

    public init(entries: [LibraryEntry], goals: [ReadingGoal], now: Date = Date(), calendar: Calendar = .current) {
        let sorted = entries.filter { $0.readingStatus == .reading }.sorted {
            let left = $0.readingSessions.map(\.startDate).max() ?? $0.addedDate
            let right = $1.readingSessions.map(\.startDate).max() ?? $1.addedDate
            return left == right ? $0.id < $1.id : left > right
        }
        book = sorted.first
        // CloudKit can briefly deliver duplicate sessions before app deduplication.
        var seen = Set<String>()
        let sessions = entries.flatMap(\.readingSessions).filter { seen.insert($0.id).inserted }
        streak = ReadingStreak.current(from: sessions, now: now, calendar: calendar)
        recentActivity = ReadingStreak.recentActivity(from: sessions, now: now, calendar: calendar)
        remainingMinutes = book.flatMap { ReadingSpeedEstimator.estimatedRemainingSeconds(for: $0) }.map { Int(ceil($0 / 60)) }
        // Long-term goals suit the home screen; smaller periods are a fallback.
        let rank: [ReadingGoal.Period: Int] = [.yearly: 0, .monthly: 1, .weekly: 2, .daily: 3]
        goal = goals.filter { $0.isActive && $0.startDate <= now }.sorted {
            let left = rank[$0.period, default: 4], right = rank[$1.period, default: 4]
            return left == right ? $0.id < $1.id : left < right
        }.first
        let progress = goal.map { GoalProgressCalculator.progress(for: $0, entries: entries, now: now, calendar: calendar) }
        goalValue = progress?.value ?? 0
        goalFraction = min(1, max(0, progress?.fraction ?? 0))
    }
}

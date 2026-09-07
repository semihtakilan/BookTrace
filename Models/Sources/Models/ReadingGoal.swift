//
//  ReadingGoal.swift
//  Models
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation

public struct ReadingGoal: Identifiable, Hashable, Sendable, Codable {
    public enum Period: String, CaseIterable, Codable, Sendable {
        case daily, weekly, monthly, yearly

        var component: Calendar.Component {
            switch self {
            case .daily: .day
            case .weekly: .weekOfYear
            case .monthly: .month
            case .yearly: .year
            }
        }
    }

    public enum Metric: String, CaseIterable, Codable, Sendable {
        case minutes, pages, books, sessions
    }

    public let id: String
    public var period: Period
    public var metric: Metric
    public var target: Int {
        didSet { target = max(1, target) }
    }
    public var startDate: Date
    public var isActive: Bool

    public init(
        id: String = UUID().uuidString,
        period: Period,
        metric: Metric,
        target: Int,
        startDate: Date = Date(),
        isActive: Bool = true
    ) {
        self.id = id
        self.period = period
        self.metric = metric
        self.target = max(1, target)
        self.startDate = startDate
        self.isActive = isActive
    }

    private enum CodingKeys: String, CodingKey { case id, period, metric, target, startDate, isActive }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try values.decode(String.self, forKey: .id),
            period: try values.decode(Period.self, forKey: .period),
            metric: try values.decode(Metric.self, forKey: .metric),
            target: try values.decode(Int.self, forKey: .target),
            startDate: try values.decode(Date.self, forKey: .startDate),
            isActive: try values.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        )
    }
}

public struct GoalProgress: Hashable, Sendable {
    public let value: Int
    public let target: Int
    public let interval: DateInterval
    public var fraction: Double { min(1, max(0, Double(value) / Double(target))) }
    public var isComplete: Bool { value >= target }
}

/// Recurring calendar periods respect the caller's locale and time zone.
/// The creation date prevents retroactive credit before a goal was started.
public enum GoalProgressCalculator {
    public static func progress(
        for goal: ReadingGoal,
        entries: [LibraryEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> GoalProgress {
        let interval = calendar.dateInterval(of: goal.period.component, for: now)
            ?? DateInterval(start: now, duration: 0)
        let start = max(interval.start, goal.startDate)
        func belongs(_ date: Date) -> Bool {
            date >= start && date < interval.end && date <= now
        }
        guard goal.isActive, goal.startDate <= now else {
            return GoalProgress(value: 0, target: goal.target, interval: interval)
        }
        let sessions = LibraryAnalytics.uniqueSessions(in: entries).filter { belongs($0.startDate) }
        let value: Int
        switch goal.metric {
        case .minutes:
            value = sessions.reduce(0) { $0 + $1.durationSeconds } / 60
        case .pages:
            value = sessions.reduce(0) { $0 + $1.pagesRead }
        case .sessions:
            value = sessions.count
        case .books:
            value = Set(entries.filter {
                $0.readingStatus == .finished && $0.finishedDate.map(belongs) == true
            }.map(\.id)).count
        }
        return GoalProgress(value: value, target: goal.target, interval: interval)
    }
}

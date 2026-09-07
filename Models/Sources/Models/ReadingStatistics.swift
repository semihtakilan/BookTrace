//
//  ReadingStatistics.swift
//  Models
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation

public struct ReadingActivityBucket: Identifiable, Hashable, Sendable {
    public let date: Date
    public let seconds: Int
    public let pages: Int
    public let sessions: Int
    public var id: Date { date }
}

public struct ReadingPacePoint: Identifiable, Hashable, Sendable {
    public let date: Date
    public let secondsPerPage: Double
    public var id: Date { date }
}

public struct ReadingHourBucket: Identifiable, Hashable, Sendable {
    public let hour: Int
    public let seconds: Int
    public let sessions: Int
    public var id: Int { hour }
}

public struct ReadingRatingBucket: Identifiable, Hashable, Sendable {
    public let rating: Int
    public let count: Int
    public var id: Int { rating }
}

public struct ReadingGenreBucket: Identifiable, Hashable, Sendable {
    public let name: String
    public let count: Int
    public var id: String { name }
}

/// A precomputed year snapshot. Views can retain this value instead of
/// re-flattening every reading session on each rendering pass.
public struct ReadingStatistics: Sendable {
    public let year: Int
    public let totalSeconds: Int
    public let totalPages: Int
    public let totalSessions: Int
    public let completedBooks: Int
    public let heatmap: [ReadingActivityBucket]
    public let monthly: [ReadingActivityBucket]
    public let pace: [ReadingPacePoint]
    public let hourly: [ReadingHourBucket]
    public let ratings: [ReadingRatingBucket]
    public let genres: [ReadingGenreBucket]
    public let averageFinishedBookSeconds: Double?
    public let averageFinishedBookPages: Double?

    public init(entries: [LibraryEntry], year: Int, calendar: Calendar = .current) {
        self.year = year
        let interval = LibraryAnalytics.yearInterval(year, calendar: calendar)
        let sessions = LibraryAnalytics.uniqueSessions(in: entries).filter {
            LibraryAnalytics.contains($0.startDate, in: interval)
        }
        let finished = LibraryAnalytics.finishedEntries(in: entries, interval: interval)
        totalSeconds = sessions.reduce(0) { $0 + $1.durationSeconds }
        totalPages = sessions.reduce(0) { $0 + $1.pagesRead }
        totalSessions = sessions.count
        completedBooks = finished.count

        let byDay = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.startDate) }
        heatmap = LibraryAnalytics.dates(in: interval, component: .day, calendar: calendar).map { date in
            Self.bucket(date: date, sessions: byDay[date] ?? [])
        }
        let byMonth = Dictionary(grouping: sessions) {
            calendar.dateInterval(of: .month, for: $0.startDate)?.start ?? $0.startDate
        }
        monthly = LibraryAnalytics.dates(in: interval, component: .month, calendar: calendar).map { date in
            Self.bucket(date: date, sessions: byMonth[date] ?? [])
        }
        // Zero-page/time sessions cannot supply a measured reading speed.
        pace = monthly.compactMap { month in
            let measured = (byMonth[month.date] ?? []).filter { $0.pagesRead > 0 && $0.durationSeconds > 0 }
            guard !measured.isEmpty else { return nil }
            return ReadingPacePoint(
                date: month.date,
                secondsPerPage: Double(measured.reduce(0) { $0 + $1.durationSeconds })
                    / Double(measured.reduce(0) { $0 + $1.pagesRead })
            )
        }
        let byHour = Dictionary(grouping: sessions) { calendar.component(.hour, from: $0.startDate) }
        hourly = (0..<24).map { hour in
            let items = byHour[hour] ?? []
            return ReadingHourBucket(hour: hour, seconds: items.reduce(0) { $0 + $1.durationSeconds }, sessions: items.count)
        }
        ratings = (1...5).map { rating in
            ReadingRatingBucket(rating: rating, count: finished.filter { $0.rating == rating }.count)
        }
        var counts: [String: Int] = [:]
        for entry in finished {
            for subject in Set(entry.book.subjects.map(LibraryAnalytics.normalized).filter { !$0.isEmpty }) {
                counts[subject, default: 0] += 1
            }
        }
        genres = counts.map { ReadingGenreBucket(name: $0.key, count: $0.value) }.sorted {
            $0.count == $1.count ? $0.name < $1.name : $0.count > $1.count
        }
        let recordedDurations = finished.compactMap { entry -> Int? in
            let seconds = LibraryAnalytics.uniqueSessions(in: [entry]).reduce(0) { $0 + $1.durationSeconds }
            return seconds > 0 ? seconds : nil
        }
        averageFinishedBookSeconds = Self.average(recordedDurations)
        averageFinishedBookPages = Self.average(finished.compactMap(\.effectivePageCount))
    }

    private static func bucket(date: Date, sessions: [ReadingSession]) -> ReadingActivityBucket {
        ReadingActivityBucket(date: date, seconds: sessions.reduce(0) { $0 + $1.durationSeconds },
                              pages: sessions.reduce(0) { $0 + $1.pagesRead }, sessions: sessions.count)
    }

    private static func average(_ values: [Int]) -> Double? {
        values.isEmpty ? nil : Double(values.reduce(0, +)) / Double(values.count)
    }
}

enum LibraryAnalytics {
    static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func uniqueSessions(in entries: [LibraryEntry]) -> [ReadingSession] {
        var sessions: [String: ReadingSession] = [:]
        for session in entries.flatMap(\.readingSessions) {
            if let existing = sessions[session.id] {
                // A deterministic winner also protects previews during an
                // incoming CloudKit merge before persistent deduplication runs.
                if session.durationSeconds > existing.durationSeconds
                    || (session.durationSeconds == existing.durationSeconds && session.pagesRead > existing.pagesRead) {
                    sessions[session.id] = session
                }
            } else {
                sessions[session.id] = session
            }
        }
        return sessions.values.sorted { $0.startDate == $1.startDate ? $0.id < $1.id : $0.startDate < $1.startDate }
    }

    static func yearInterval(_ year: Int, calendar: Calendar) -> DateInterval {
        let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? .distantPast
        let end = calendar.date(byAdding: .year, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    static func contains(_ date: Date, in interval: DateInterval) -> Bool {
        date >= interval.start && date < interval.end
    }

    static func finishedEntries(in entries: [LibraryEntry], interval: DateInterval) -> [LibraryEntry] {
        var ids = Set<String>()
        return entries.filter {
            $0.readingStatus == .finished
                && $0.finishedDate.map { contains($0, in: interval) } == true
                && ids.insert($0.id).inserted
        }
    }

    static func dates(in interval: DateInterval, component: Calendar.Component, calendar: Calendar) -> [Date] {
        var dates: [Date] = []
        var cursor = interval.start
        while cursor < interval.end {
            dates.append(cursor)
            guard let next = calendar.date(byAdding: component, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }
        return dates
    }
}

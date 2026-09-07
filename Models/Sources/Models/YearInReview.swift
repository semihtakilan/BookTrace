//
//  YearInReview.swift
//  Models
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation

public struct YearInReview: Sendable {
    public let year: Int
    public let totalBooks: Int
    public let totalPages: Int
    public let totalSeconds: Int
    public let longestStreak: Int
    public let fastestBook: BookReference?
    public let topGenre: String?
    public let bookOfYear: BookReference?

    public init(entries: [LibraryEntry], year: Int, calendar: Calendar = .current) {
        self.year = year
        let statistics = ReadingStatistics(entries: entries, year: year, calendar: calendar)
        totalBooks = statistics.completedBooks
        totalPages = statistics.totalPages
        totalSeconds = statistics.totalSeconds
        topGenre = statistics.genres.first?.name
        var run = 0
        var best = 0
        for day in statistics.heatmap {
            run = day.sessions > 0 ? run + 1 : 0
            best = max(best, run)
        }
        longestStreak = best

        let finished = LibraryAnalytics.finishedEntries(in: entries, interval: LibraryAnalytics.yearInterval(year, calendar: calendar))
        fastestBook = finished.filter(\.hasPersonalizedSpeed).sorted {
            $0.secondsPerPage == $1.secondsPerPage ? $0.id < $1.id : $0.secondsPerPage < $1.secondsPerPage
        }.first?.book
        bookOfYear = finished.filter { $0.rating != nil }.sorted {
            if $0.rating != $1.rating { return ($0.rating ?? 0) > ($1.rating ?? 0) }
            if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
            return $0.id < $1.id
        }.first?.book
    }
}

//
//  ProfileViewModelTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation
import Models
import Testing
@testable import BookTrace

@MainActor
struct ProfileViewModelTests {

    private func makeViewModel(_ entries: [LibraryEntry]) -> ProfileViewModel {
        let repository = LibraryRepositoryMock()
        repository.storedEntries = entries
        let viewModel = ProfileViewModel(libraryRepository: repository)
        viewModel.load()
        return viewModel
    }

    @Test func anEmptyLibraryReportsNoMeasuredPace() {
        let viewModel = makeViewModel([])

        #expect(viewModel.isEmpty)
        #expect(viewModel.secondsPerPage == nil)
        #expect(viewModel.pagesPerHour == nil)
        #expect(viewModel.estimatedRemainingSeconds == nil)
    }

    @Test func activityUsesLocalCalendarDaysAndIncludesEmptyDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 3 * 3600))
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 4)))
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let oldDay = try #require(calendar.date(byAdding: .day, value: -7, to: today))
        let viewModel = makeViewModel([
            makeEntry(sessions: [
                ReadingSession(startDate: today.addingTimeInterval(60), durationSeconds: 300, pagesRead: 4),
                ReadingSession(startDate: today.addingTimeInterval(600), durationSeconds: 120, pagesRead: 2),
                ReadingSession(startDate: yesterday.addingTimeInterval(60), durationSeconds: 90, pagesRead: 1),
                ReadingSession(startDate: oldDay, durationSeconds: 900, pagesRead: 10)
            ])
        ])
        viewModel.load(now: today.addingTimeInterval(3600), calendar: calendar)

        #expect(viewModel.recentDays.count == 7)
        #expect(viewModel.recentDays.last?.date == today)
        #expect(viewModel.recentDays.map(\.seconds) == [0, 0, 0, 0, 0, 90, 420])
        #expect(viewModel.totalReadSeconds == 1410)
    }

    @Test func paceIsMeasuredAcrossTheWholeLibrary() {
        let viewModel = makeViewModel([
            makeEntry(id: "a", pageCount: 100, currentPage: 20,
                      sessions: [ReadingSession(startDate: Date(), durationSeconds: 600, pagesRead: 20)]),
            makeEntry(id: "b", pageCount: 100, currentPage: 10,
                      sessions: [ReadingSession(startDate: Date(), durationSeconds: 300, pagesRead: 10)])
        ])

        // 900 saniye / 30 sayfa = 30 saniye
        #expect(viewModel.secondsPerPage == 30)
        #expect(viewModel.pagesPerHour == 120)
        #expect(viewModel.totalReadSeconds == 900)
        #expect(viewModel.totalPagesRead == 30)
        #expect(viewModel.sessionCount == 2)
    }

    /// B4: "Left to finish" ile hemen üstündeki "Your Pace" kartı aynı hızı
    /// kullanmalı. Önceden kalan süre her kitabın kendi hızından hesaplanıyordu
    /// ve hiç oturumu olmayan kitaplar sayfa başına 120 saniyelik varsayılana
    /// düşüyordu — aynı ekranda iki farklı hız tanımı görünüyordu.
    @Test func theRemainingEstimateUsesTheSamePaceTheScreenDisplays() throws {
        let measured = makeEntry(
            id: "measured", readingStatus: .reading, pageCount: 100, currentPage: 20,
            sessions: [ReadingSession(startDate: Date(), durationSeconds: 600, pagesRead: 20)]
        )
        let untouched = makeEntry(id: "untouched", readingStatus: .toRead, pageCount: 100)

        let viewModel = makeViewModel([measured, untouched])

        let pace = try #require(viewModel.secondsPerPage)
        #expect(pace == 30)

        // Kalan 80 + 100 sayfa, ölçülen 30 sn/sayfa ile.
        #expect(viewModel.estimatedRemainingSeconds == 5_400)
        // Kitap başına hız kullanılsaydı 80×30 + 100×120 = 14 400 çıkardı.
        #expect(viewModel.estimatedRemainingSeconds != 14_400)
    }

    @Test func withoutAnySessionTheDefaultPaceDrivesTheEstimate() {
        let viewModel = makeViewModel([
            makeEntry(id: "a", readingStatus: .toRead, pageCount: 10)
        ])

        #expect(viewModel.secondsPerPage == nil)
        #expect(viewModel.estimatedRemainingSeconds == 10 * ReadingSpeedEstimator.defaultSecondsPerPage)
    }

    @Test func finishedBooksDoNotCountTowardsWhatIsLeft() {
        let viewModel = makeViewModel([
            makeEntry(id: "done", readingStatus: .finished, pageCount: 100, currentPage: 100),
            makeEntry(id: "abandoned", readingStatus: .abandoned, pageCount: 100)
        ])

        #expect(viewModel.estimatedRemainingSeconds == nil)
        #expect(viewModel.finishedCount == 1)
    }

    @Test func breakdownsSkipEmptyBucketsAndKeepTheirDeclaredOrder() {
        let viewModel = makeViewModel([
            makeEntry(id: "a", readingStatus: .reading, ownershipStatus: .owned),
            makeEntry(id: "b", readingStatus: .finished, ownershipStatus: .owned),
            makeEntry(id: "c", readingStatus: .finished, ownershipStatus: .borrowed)
        ])

        #expect(viewModel.statusBreakdown.map(\.status) == [.reading, .finished])
        #expect(viewModel.statusBreakdown.map(\.count) == [1, 2])
        #expect(viewModel.ownershipBreakdown.map(\.status) == [.borrowed, .owned])
    }

    @Test func recentSessionsAreTheFiveNewestAcrossEveryBook() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let sessions = (0..<4).map {
            ReadingSession(id: "s\($0)", startDate: start.addingTimeInterval(Double($0) * 3_600),
                           durationSeconds: 600, pagesRead: 10)
        }
        let viewModel = makeViewModel([
            makeEntry(id: "a", title: "Dune", pageCount: 500, sessions: Array(sessions.prefix(2))),
            makeEntry(id: "b", title: "Anathem", pageCount: 500, sessions: Array(sessions.suffix(2)))
        ])

        #expect(viewModel.recentSessions.count == 4)
        #expect(viewModel.recentSessions.map(\.id) == ["s3", "s2", "s1", "s0"])
        #expect(viewModel.recentSessions.first?.bookTitle == "Anathem")
    }
}

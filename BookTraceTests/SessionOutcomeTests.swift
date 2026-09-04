//
//  SessionOutcomeTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 04.09.2026.
//

import Foundation
import Models
import Testing
@testable import BookTrace

@MainActor
struct SessionOutcomeTests {

    private func entry(pageCount: Int, currentPage: Int, sessions: Int,
                       status: ReadingStatus = .reading) -> LibraryEntry {
        LibraryEntry(
            book: BookReference(id: "book-1", title: "A Book", pageCount: pageCount),
            readingStatus: status,
            currentPage: currentPage,
            readingSessions: (0..<sessions).map {
                ReadingSession(id: "s\($0)", startDate: Date(), durationSeconds: 600, pagesRead: 5)
            }
        )
    }

    @Test func finishingTheBookOutranksEveryOtherOutcome() {
        let outcome = SessionOutcome(
            fractionBefore: 0.4,
            entry: entry(pageCount: 100, currentPage: 100, sessions: 3, status: .finished),
            pagesRead: 60
        )

        #expect(outcome == .finishedBook)
    }

    @Test func crossingAQuarterIsCelebrated() {
        let outcome = SessionOutcome(
            fractionBefore: 0.02,
            entry: entry(pageCount: 246, currentPage: 82, sessions: 2),
            pagesRead: 77
        )

        #expect(outcome == .milestone(percent: 25))
    }

    @Test func theHighestCrossedThresholdWins() {
        // 10%'den 80%'e atlayan bir oturum üç eşiği birden geçiyor; kutlama
        // bunların en yükseğini söylemeli.
        let outcome = SessionOutcome(
            fractionBefore: 0.10,
            entry: entry(pageCount: 100, currentPage: 80, sessions: 2),
            pagesRead: 70
        )

        #expect(outcome == .milestone(percent: 75))
    }

    @Test func anAlreadyPassedThresholdIsNotCelebratedAgain() {
        let outcome = SessionOutcome(
            fractionBefore: 0.55,
            entry: entry(pageCount: 100, currentPage: 60, sessions: 4),
            pagesRead: 5
        )

        #expect(outcome == nil)
    }

    @Test func theFirstRealSessionIsCelebrated() {
        let outcome = SessionOutcome(
            fractionBefore: 0,
            entry: entry(pageCount: 400, currentPage: 6, sessions: 1),
            pagesRead: 6
        )

        #expect(outcome == .firstSession)
    }

    @Test func aFirstSessionWithoutPagesIsNotAnEvent() {
        // Yalnızca süre kaydeden bir oturum da geçerli, ama kutlanacak bir şey değil.
        let outcome = SessionOutcome(
            fractionBefore: 0,
            entry: entry(pageCount: 400, currentPage: 0, sessions: 1),
            pagesRead: 0
        )

        #expect(outcome == nil)
    }

    @Test func aBookWithoutAKnownLengthStillCelebratesItsFirstSession() {
        let unknownLength = LibraryEntry(
            book: BookReference(id: "book-2", title: "No Length"),
            readingStatus: .reading,
            currentPage: 12,
            readingSessions: [ReadingSession(startDate: Date(), durationSeconds: 300, pagesRead: 12)]
        )

        #expect(SessionOutcome(fractionBefore: 0, entry: unknownLength, pagesRead: 12) == .firstSession)
    }
}

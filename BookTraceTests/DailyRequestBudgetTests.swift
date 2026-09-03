//
//  DailyRequestBudgetTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 04.09.2026.
//

import Foundation
import Testing
@testable import BookTrace

@Suite struct DailyRequestBudgetTests {

    private func makeSuiteName() -> String {
        UUID().uuidString
    }

    @Test func requestsAreAllowedUpToTheDailyLimit() async {
        let budget = DailyRequestBudget(limit: 3, suiteName: makeSuiteName())

        #expect(await budget.consume())
        #expect(await budget.consume())
        #expect(await budget.consume())
        #expect(await budget.consume() == false)
    }

    @Test func theCounterReportsWhatWasSpent() async {
        let budget = DailyRequestBudget(limit: 5, suiteName: makeSuiteName())

        _ = await budget.consume()
        _ = await budget.consume()

        #expect(await budget.spentToday() == 2)
    }

    /// Sayaç `UserDefaults`'ta duruyor; uygulama kapanıp açıldığında tavan
    /// sıfırlanmamalı, yoksa tavanın hiçbir anlamı kalmaz.
    @Test func theBudgetSurvivesARestart() async {
        let suiteName = makeSuiteName()
        let first = DailyRequestBudget(limit: 2, suiteName: suiteName)

        _ = await first.consume()
        _ = await first.consume()

        let afterRestart = DailyRequestBudget(limit: 2, suiteName: suiteName)
        #expect(await afterRestart.consume() == false)
    }

    /// Gün dönünce sayaç sıfırlanıyor.
    @Test func aNewDayStartsWithAFullBudget() async {
        let suiteName = makeSuiteName()
        let defaults = UserDefaults(suiteName: suiteName)!
        let yesterday = Calendar.current.startOfDay(for: Date(timeIntervalSinceNow: -.days(1)))
        defaults.set(yesterday, forKey: "GoogleBooksBudget.day")
        defaults.set(99, forKey: "GoogleBooksBudget.count")

        let budget = DailyRequestBudget(limit: 2, suiteName: suiteName)

        #expect(await budget.consume())
        #expect(await budget.spentToday() == 1)
    }

    /// Kota hatasından sonra kaynak bir süre kapalı: tavanın altında olsak bile
    /// istek gitmiyor, hepsi Open Library'ye düşüyor.
    @Test func aQuotaFailureSuspendsTheSourceEvenWithBudgetLeft() async {
        let budget = DailyRequestBudget(limit: 10, suiteName: makeSuiteName())

        await budget.recordQuotaFailure()

        #expect(await budget.consume() == false)
    }

    /// Kesici süreli: geçmiş bir tarih artık engellemiyor.
    @Test func theSuspensionLiftsOnceItsWindowHasPassed() async {
        let suiteName = makeSuiteName()
        UserDefaults(suiteName: suiteName)!.set(
            Date(timeIntervalSinceNow: -60),
            forKey: "GoogleBooksBudget.blockedUntil"
        )

        let budget = DailyRequestBudget(limit: 10, suiteName: suiteName)

        #expect(await budget.consume())
    }
}

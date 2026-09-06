//
//  ReadingSpeedEstimatorValidationTests.swift
//  ModelsTests
//
//  Created by Semih TAKILAN on 06.09.2026.
//

import Foundation
import Testing
@testable import Models

struct ReadingSpeedEstimatorValidationTests {
    @Test func unmeasuredPagesDoNotDistortRecordedPace() {
        let sessions = [
            ReadingSession(startDate: .distantPast, durationSeconds: 600, pagesRead: 10),
            ReadingSession(startDate: .distantPast, durationSeconds: 0, pagesRead: 90),
            ReadingSession(startDate: .distantPast, durationSeconds: 900, pagesRead: 0)
        ]

        #expect(ReadingSpeedEstimator.secondsPerPage(for: sessions) == 60)
        #expect(ReadingSpeedEstimator.hasPersonalizedSpeed(for: sessions))
    }

    @Test func separateTimeOnlyAndUntimedPagesAreNotAPaceMeasurement() {
        let sessions = [
            ReadingSession(startDate: .distantPast, durationSeconds: 0, pagesRead: 10),
            ReadingSession(startDate: .distantPast, durationSeconds: 600, pagesRead: 0)
        ]

        #expect(!ReadingSpeedEstimator.hasPersonalizedSpeed(for: sessions))
        #expect(ReadingSpeedEstimator.secondsPerPage(for: sessions)
                == ReadingSpeedEstimator.defaultSecondsPerPage)
    }
}

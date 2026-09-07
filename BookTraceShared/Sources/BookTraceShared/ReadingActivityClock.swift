//
//  ReadingActivityClock.swift
//  BookTraceShared
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation

/// The effective start excludes all previous pauses. System timer rendering can
/// keep counting while the app is suspended, without a per-second Activity update.
public struct ReadingActivityClock: Codable, Hashable, Sendable {
    public var startDate: Date
    public var pausedElapsed: TimeInterval?

    public init(accumulatedSeconds: TimeInterval, runningSince: Date?, now: Date) {
        let accumulated = max(0, accumulatedSeconds)
        startDate = (runningSince ?? now).addingTimeInterval(-accumulated)
        pausedElapsed = runningSince == nil ? accumulated : nil
    }

    public func elapsed(at date: Date) -> TimeInterval {
        max(0, pausedElapsed ?? date.timeIntervalSince(startDate))
    }

    public var isPaused: Bool { pausedElapsed != nil }
}

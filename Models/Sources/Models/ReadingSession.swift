//
//  ReadingSession.swift
//  Models
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Foundation

/// Tek bir okuma oturumunun kaydı: ne zaman başladı, ne kadar sürdü, kaç sayfa okundu.
///
/// Hız tahmininin (`ReadingSpeedEstimator`) tek veri kaynağıdır.
public struct ReadingSession: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let startDate: Date
    public let durationSeconds: Int
    public let pagesRead: Int

    public var endDate: Date {
        startDate.addingTimeInterval(TimeInterval(durationSeconds))
    }

    public init(
        id: String = UUID().uuidString,
        startDate: Date,
        durationSeconds: Int,
        pagesRead: Int
    ) {
        self.id = id
        self.startDate = startDate
        self.durationSeconds = max(0, durationSeconds)
        self.pagesRead = max(0, pagesRead)
    }
}

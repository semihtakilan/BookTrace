//
//  LocalReadingSessionModel.swift
//  Persistence
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Foundation
import Models
import SwiftData

/// Bir okuma oturumunun kalıcı karşılığı.
@Model
final class LocalReadingSessionModel {
    @Attribute(.unique) var id: String
    var startDate: Date
    var durationSeconds: Int
    var pagesRead: Int

    /// `LocalLibraryEntryModel.readingSessions` ilişkisinin ters ucu.
    var libraryEntry: LocalLibraryEntryModel?

    init(session: ReadingSession) {
        id = session.id
        startDate = session.startDate
        durationSeconds = session.durationSeconds
        pagesRead = session.pagesRead
    }

    func toDomain() -> ReadingSession {
        ReadingSession(
            id: id,
            startDate: startDate,
            durationSeconds: durationSeconds,
            pagesRead: pagesRead
        )
    }
}

//
//  ProfileViewModel.swift
//  Profile
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Foundation
import Models
import Observation

/// Profil ekranında listelenen bir okuma oturumu — hangi kitaba ait olduğuyla birlikte.
struct RecentReadingSession: Identifiable {
    let id: String
    let bookTitle: String
    let startDate: Date
    let durationSeconds: Int
    let pagesRead: Int
}

/// Profil sekmesinin verisi.
///
/// Hepsi kütüphanedeki kayıtlardan türetilir; ağ çağrısı yoktur. Hız hesabı
/// tek kitap yerine tüm oturumlar üzerinden yapılır, böylece "genel okuma
/// hızın" kitaptan bağımsız bir değer olarak çıkar.
@MainActor
@Observable
final class ProfileViewModel {
    private(set) var entries: [LibraryEntry] = []
    var errorMessage: String?

    @ObservationIgnored
    private let libraryRepository: any LibraryRepository

    init(libraryRepository: any LibraryRepository) {
        self.libraryRepository = libraryRepository
    }

    var isEmpty: Bool { entries.isEmpty }

    // MARK: - Kütüphane özeti

    var bookCount: Int { entries.count }
    var finishedCount: Int { entries.filter { $0.readingStatus == .finished }.count }
    var readingCount: Int { entries.filter { $0.readingStatus == .reading }.count }

    // MARK: - Okuma etkinliği

    private var allSessions: [ReadingSession] {
        entries.flatMap(\.readingSessions)
    }

    var sessionCount: Int { allSessions.count }
    var totalReadSeconds: Int { allSessions.reduce(0) { $0 + $1.durationSeconds } }
    var totalPagesRead: Int { allSessions.reduce(0) { $0 + $1.pagesRead } }

    /// Tüm kütüphane üzerinden ölçülen sayfa başına süre. Hiç oturum yoksa `nil` —
    /// bu durumda ekran varsayılan tahminin kullanıldığını söyler.
    var secondsPerPage: TimeInterval? {
        guard ReadingSpeedEstimator.hasPersonalizedSpeed(for: allSessions) else { return nil }
        return ReadingSpeedEstimator.secondsPerPage(for: allSessions)
    }

    var pagesPerHour: Int? {
        guard let secondsPerPage, secondsPerPage > 0 else { return nil }
        return Int((3600 / secondsPerPage).rounded())
    }

    /// Kütüphanedeki tüm kitapları bitirmek için kalan tahmini süre.
    var estimatedRemainingSeconds: TimeInterval? {
        let remaining = entries
            .filter { $0.readingStatus == .reading || $0.readingStatus == .toRead }
            .compactMap(\.estimatedRemainingSeconds)
            .reduce(0, +)
        return remaining > 0 ? remaining : nil
    }

    // MARK: - Dağılımlar

    var statusBreakdown: [(status: ReadingStatus, count: Int)] {
        let grouped = Dictionary(grouping: entries, by: \.readingStatus)
        return ReadingStatus.allCases.compactMap { status in
            guard let count = grouped[status]?.count, count > 0 else { return nil }
            return (status, count)
        }
    }

    var ownershipBreakdown: [(status: OwnershipStatus, count: Int)] {
        let grouped = Dictionary(grouping: entries, by: \.ownershipStatus)
        return OwnershipStatus.allCases.compactMap { status in
            guard let count = grouped[status]?.count, count > 0 else { return nil }
            return (status, count)
        }
    }

    var recentSessions: [RecentReadingSession] {
        entries
            .flatMap { entry in
                entry.readingSessions.map {
                    RecentReadingSession(
                        id: $0.id,
                        bookTitle: entry.book.title,
                        startDate: $0.startDate,
                        durationSeconds: $0.durationSeconds,
                        pagesRead: $0.pagesRead
                    )
                }
            }
            .sorted { $0.startDate > $1.startDate }
            .prefix(5)
            .map { $0 }
    }

    func load() {
        do {
            entries = try libraryRepository.fetchEntries()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

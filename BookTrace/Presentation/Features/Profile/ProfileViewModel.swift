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
///
/// Türetilmiş değerlerin hepsi `load()` içinde bir kez hesaplanıp saklanır.
/// `@Observable` computed property'leri önbelleklemiyor; bunlar `var { … }`
/// olsaydı `recentSessions` her yeniden çizimde tüm oturumları düzleyip
/// sıralardı.
@MainActor
@Observable
final class ProfileViewModel {
    private(set) var entries: [LibraryEntry] = []
    var error: UserFacingError?

    // MARK: - Kütüphane özeti
    private(set) var bookCount = 0
    private(set) var finishedCount = 0
    private(set) var readingCount = 0

    // MARK: - Okuma etkinliği
    private(set) var sessionCount = 0
    private(set) var totalReadSeconds = 0
    private(set) var totalPagesRead = 0

    /// Tüm kütüphane üzerinden ölçülen sayfa başına süre. Hiç oturum yoksa `nil` —
    /// bu durumda ekran varsayılan tahminin kullanıldığını söyler.
    private(set) var secondsPerPage: TimeInterval?
    private(set) var pagesPerHour: Int?
    /// Kütüphanedeki tüm kitapları bitirmek için kalan tahmini süre.
    private(set) var estimatedRemainingSeconds: TimeInterval?

    // MARK: - Dağılımlar
    private(set) var statusBreakdown: [(status: ReadingStatus, count: Int)] = []
    private(set) var ownershipBreakdown: [(status: OwnershipStatus, count: Int)] = []
    private(set) var recentSessions: [RecentReadingSession] = []

    @ObservationIgnored
    private let libraryRepository: any LibraryRepository

    init(libraryRepository: any LibraryRepository) {
        self.libraryRepository = libraryRepository
    }

    var isEmpty: Bool { entries.isEmpty }

    func load() {
        do {
            entries = try libraryRepository.fetchEntries()
            self.error = nil
        } catch {
            self.error = UserFacingError(error)
        }
        recalculate()
    }

    private func recalculate() {
        bookCount = entries.count
        finishedCount = entries.filter { $0.readingStatus == .finished }.count
        readingCount = entries.filter { $0.readingStatus == .reading }.count

        let allSessions = entries.flatMap(\.readingSessions)
        sessionCount = allSessions.count
        totalReadSeconds = allSessions.reduce(0) { $0 + $1.durationSeconds }
        totalPagesRead = allSessions.reduce(0) { $0 + $1.pagesRead }

        secondsPerPage = ReadingSpeedEstimator.hasPersonalizedSpeed(for: allSessions)
            ? ReadingSpeedEstimator.secondsPerPage(for: allSessions)
            : nil
        pagesPerHour = secondsPerPage.flatMap { pace in
            pace > 0 ? Int((3600 / pace).rounded()) : nil
        }
        estimatedRemainingSeconds = makeEstimatedRemainingSeconds()

        statusBreakdown = makeStatusBreakdown()
        ownershipBreakdown = makeOwnershipBreakdown()
        recentSessions = makeRecentSessions()
    }

    /// Kalan süre, hemen altındaki "Your Pace" kartının gösterdiği hızın
    /// aynısıyla hesaplanır.
    ///
    /// Önceden her kitap kendi hızını kullanıyordu; hiç oturumu olmayan
    /// kitaplar sayfa başına 120 saniyelik varsayılana düşüyordu. Sonuç, aynı
    /// ekranda "sayfa başına 30 saniye okuyorsun" derken toplam kalan süreyi
    /// 120 sn/sayfa üzerinden veren bir çelişkiydi.
    private func makeEstimatedRemainingSeconds() -> TimeInterval? {
        let pace = secondsPerPage ?? ReadingSpeedEstimator.defaultSecondsPerPage
        let remainingPages = entries
            .filter { $0.readingStatus == .reading || $0.readingStatus == .toRead }
            .compactMap(\.remainingPages)
            .reduce(0, +)
        guard remainingPages > 0 else { return nil }
        return TimeInterval(remainingPages) * pace
    }

    private func makeStatusBreakdown() -> [(status: ReadingStatus, count: Int)] {
        let grouped = Dictionary(grouping: entries, by: \.readingStatus)
        return ReadingStatus.allCases.compactMap { status in
            guard let count = grouped[status]?.count, count > 0 else { return nil }
            return (status, count)
        }
    }

    private func makeOwnershipBreakdown() -> [(status: OwnershipStatus, count: Int)] {
        let grouped = Dictionary(grouping: entries, by: \.ownershipStatus)
        return OwnershipStatus.allCases.compactMap { status in
            guard let count = grouped[status]?.count, count > 0 else { return nil }
            return (status, count)
        }
    }

    private func makeRecentSessions() -> [RecentReadingSession] {
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
}

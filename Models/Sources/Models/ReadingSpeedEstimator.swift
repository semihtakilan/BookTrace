//
//  ReadingSpeedEstimator.swift
//  Models
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Foundation

/// Kalan okuma süresi tahmini.
///
/// Hiç oturum yokken sayfa başına sabit bir varsayım kullanır; kitabın kendi
/// oturumları biriktikçe tahmin o kitaba ve o kullanıcıya özel hâle gelir.
/// Saf ve durumsuz tutulmuştur ki birim testleri UI'a bağlanmadan yazılabilsin.
public enum ReadingSpeedEstimator {
    /// Hiç ölçüm yokken kullanılan başlangıç varsayımı: sayfa başına 2 dakika.
    public static let defaultSecondsPerPage: TimeInterval = 120

    public static func hasPersonalizedSpeed(for sessions: [ReadingSession]) -> Bool {
        totalPages(in: sessions) > 0 && totalSeconds(in: sessions) > 0
    }

    /// Oturumların toplam süresi ÷ toplam okunan sayfa. Ölçüm yoksa varsayılan.
    public static func secondsPerPage(for sessions: [ReadingSession]) -> TimeInterval {
        let pages = totalPages(in: sessions)
        let seconds = totalSeconds(in: sessions)
        guard pages > 0, seconds > 0 else { return defaultSecondsPerPage }
        return TimeInterval(seconds) / TimeInterval(pages)
    }

    public static func estimatedRemainingSeconds(for entry: LibraryEntry) -> TimeInterval? {
        guard let remaining = entry.remainingPages, remaining > 0 else { return nil }
        return TimeInterval(remaining) * secondsPerPage(for: entry.readingSessions)
    }

    private static func totalPages(in sessions: [ReadingSession]) -> Int {
        sessions.reduce(0) { $0 + $1.pagesRead }
    }

    private static func totalSeconds(in sessions: [ReadingSession]) -> Int {
        sessions.reduce(0) { $0 + $1.durationSeconds }
    }
}

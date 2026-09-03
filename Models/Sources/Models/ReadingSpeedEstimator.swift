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
        let measured = measurable(sessions)
        return totalPages(in: measured) > 0 && totalSeconds(in: measured) > 0
    }

    /// Oturumların toplam süresi ÷ toplam okunan sayfa. Ölçüm yoksa varsayılan.
    public static func secondsPerPage(for sessions: [ReadingSession]) -> TimeInterval {
        let measured = measurable(sessions)
        let pages = totalPages(in: measured)
        let seconds = totalSeconds(in: measured)
        guard pages > 0, seconds > 0 else { return defaultSecondsPerPage }
        return TimeInterval(seconds) / TimeInterval(pages)
    }

    public static func estimatedRemainingSeconds(for entry: LibraryEntry) -> TimeInterval? {
        guard let remaining = entry.remainingPages, remaining > 0 else { return nil }
        return TimeInterval(remaining) * secondsPerPage(for: entry.readingSessions)
    }

    /// Hız hesabına yalnızca sayfa okunmuş oturumlar girer.
    ///
    /// Sayfa girilmemiş bir oturum süreyi paya ekler, paydaya hiçbir şey
    /// eklemez; tek bir "45 dakika okudum, sayfa girmedim" kaydı o kitabın
    /// sayfa başına süresini kalıcı olarak şişirir. Oturum silme arayüzü
    /// olmadığı için kullanıcının bunu düzeltme yolu da yok. Bu yüzden filtre
    /// hesabın kendisinde: geçmişte kaydedilmiş bozuk veriler de böylece
    /// tahmini bozmaktan çıkar. Süre toplamları (`LibraryEntry.totalReadSeconds`)
    /// bu filtreden etkilenmez — o oturumlar gerçekten okunmuş zamandır.
    private static func measurable(_ sessions: [ReadingSession]) -> [ReadingSession] {
        sessions.filter { $0.pagesRead > 0 }
    }

    private static func totalPages(in sessions: [ReadingSession]) -> Int {
        sessions.reduce(0) { $0 + $1.pagesRead }
    }

    private static func totalSeconds(in sessions: [ReadingSession]) -> Int {
        sessions.reduce(0) { $0 + $1.durationSeconds }
    }
}

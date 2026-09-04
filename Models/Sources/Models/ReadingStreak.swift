//
//  ReadingStreak.swift
//  Models
//
//  Created by Semih TAKILAN on 04.09.2026.
//

import Foundation

/// Üst üste okunan günler.
///
/// Uygulamanın tek "oyunlaştırma" öğesi ve bilinçli olarak yumuşak: bugün henüz
/// okumadıysan seri kırılmış sayılmaz, çünkü gün bitmedi. Kullanıcıyı akşam
/// dokuzda telaşlandırmanın kimseye faydası yok.
public enum ReadingStreak {

    /// Bugün ya da dün biten kesintisiz okuma günü sayısı.
    public static func current(
        from sessions: [ReadingSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let readDays = Set(sessions.map { calendar.startOfDay(for: $0.startDate) })
        guard !readDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }

        // Seri bugünden ya da dünden geriye sayılır. Bugün okunmadıysa dünkü
        // seri hâlâ ayakta.
        var cursor = readDays.contains(today) ? today : yesterday
        guard readDays.contains(cursor) else { return 0 }

        var count = 0
        while readDays.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    /// Son `days` günün her biri için o gün okunup okunmadığı; en eskiden bugüne.
    public static func recentActivity(
        from sessions: [ReadingSession],
        days: Int = 7,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Bool] {
        guard days > 0 else { return [] }
        let readDays = Set(sessions.map { calendar.startOfDay(for: $0.startDate) })
        let today = calendar.startOfDay(for: now)

        return (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return readDays.contains(date)
        }
    }
}

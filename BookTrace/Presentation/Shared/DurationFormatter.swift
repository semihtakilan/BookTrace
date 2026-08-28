//
//  DurationFormatter.swift
//  Shared
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Foundation

/// Okuma sürelerini ekranda okunur hâle getirir.
enum DurationFormatter {

    /// Sayaç görünümü: `01:23` veya bir saati geçince `1:04:07`.
    static func timer(seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        let hours = safeSeconds / 3600
        let minutes = (safeSeconds % 3600) / 60
        let remainder = safeSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%02d:%02d", minutes, remainder)
    }

    /// Özet görünümü: `2sa 15dk`, `45dk`, `30sn`.
    static func compact(seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        let hours = safeSeconds / 3600
        let minutes = (safeSeconds % 3600) / 60

        if hours > 0 {
            return minutes > 0 ? "\(hours)sa \(minutes)dk" : "\(hours)sa"
        }
        if minutes > 0 {
            return "\(minutes)dk"
        }
        return "\(safeSeconds)sn"
    }

    static func compact(seconds: TimeInterval) -> String {
        compact(seconds: Int(seconds.rounded()))
    }
}

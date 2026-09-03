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
    ///
    /// Bilinçli olarak yerelleştirilmiyor — sayaç her dilde aynı biçimde okunur.
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

    /// Özet görünümü: `2h 15m`, `45m`, `30s` — ve seçilen dilde karşılıkları.
    ///
    /// Birimler elle yazılıyordu, bu yüzden Türkçe ve Almanca arayüzde de
    /// İngilizce kalıyordu. `Duration.formatted` birimleri yerelden alır.
    static func compact(seconds: Int, locale: Locale) -> String {
        Duration.seconds(max(0, seconds)).formatted(
            .units(
                allowed: [.hours, .minutes, .seconds],
                width: .narrow,
                maximumUnitCount: 2
            )
            .locale(locale)
        )
    }

    static func compact(seconds: TimeInterval, locale: Locale) -> String {
        compact(seconds: Int(seconds.rounded()), locale: locale)
    }
}

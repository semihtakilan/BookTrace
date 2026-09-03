//
//  DailyRequestBudget.swift
//  Services
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation
import Models

/// Google Books isteklerini cihaz başına günlük bir tavana bağlar ve kota
/// hatasından sonra kaynağı bir süre devre dışı bırakır.
///
/// Google'ın tavanı proje başına: uygulamayı kullanan herkes aynı havuzdan
/// harcıyor. Tek bir cihazın gün boyu arama yapması, hiç kimsenin arama
/// yapamamasına yol açabilir. Buradaki tavan bunu engelliyor — ve tavana
/// çarpmak bir arıza değil: istekler Open Library'ye düşüyor, kullanıcı
/// kesinti görmüyor.
///
/// Sayaç `UserDefaults`'ta; uygulama kapanıp açıldığında sıfırlanmaması
/// gerekiyor, ama kaybolması da felaket değil.
actor DailyRequestBudget: RequestBudget {
    private let limit: Int
    private let defaults: UserDefaults
    private let calendar: Calendar

    private static let countKey = "GoogleBooksBudget.count"
    private static let dayKey = "GoogleBooksBudget.day"
    private static let blockedUntilKey = "GoogleBooksBudget.blockedUntil"

    /// Kota hatasından sonra kaynağın kapalı kalacağı süre.
    ///
    /// Google'ın günlük sayacı Pasifik saatiyle geceyarısı sıfırlanıyor; o ana
    /// kadar beklemek yerine bir saat sonra yeniden deniyoruz. Kotayı asıl
    /// tüketen başka bir kullanıcıysa bir saat sonra durum değişmiş olabilir.
    private static let blockDuration: TimeInterval = 60 * 60

    init(limit: Int = 25, defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.limit = limit
        self.defaults = defaults
        self.calendar = calendar
    }

    func consume() async -> Bool {
        let now = Date()

        if let blockedUntil = defaults.object(forKey: Self.blockedUntilKey) as? Date, now < blockedUntil {
            return false
        }

        let today = calendar.startOfDay(for: now)
        let storedDay = defaults.object(forKey: Self.dayKey) as? Date
        let count = storedDay == today ? defaults.integer(forKey: Self.countKey) : 0

        guard count < limit else { return false }

        defaults.set(count + 1, forKey: Self.countKey)
        defaults.set(today, forKey: Self.dayKey)
        return true
    }

    func recordQuotaFailure() async {
        defaults.set(Date().addingTimeInterval(Self.blockDuration), forKey: Self.blockedUntilKey)
    }

    /// Bugün kaç istek harcandığı; hata ayıklama ekranı için.
    func spentToday() -> Int {
        let today = calendar.startOfDay(for: Date())
        guard defaults.object(forKey: Self.dayKey) as? Date == today else { return 0 }
        return defaults.integer(forKey: Self.countKey)
    }
}

/// Kota hatalarını politikanın anlayacağı biçimde bildirir.
extension GoogleBooksServiceError: QuotaFailureReporting {
    var isQuotaFailure: Bool {
        if case .quotaExceeded = self { return true }
        return false
    }
}

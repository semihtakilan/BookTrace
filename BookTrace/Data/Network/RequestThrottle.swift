//
//  RequestThrottle.swift
//  Network
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation

/// İstekler arasına en az bir aralık koyan sıralayıcı.
///
/// Open Library istek hızını IP başına sınırlıyor: kendini tanıtmayan istemci
/// saniyede bir, uygulama adı ve iletişim adresi veren saniyede üç istek.
/// Explore açılışta altı rafı birden istiyor; hepsi aynı anda giderse sınırın
/// üstüne çıkıp 429 alırız. Burası çağrıları sıraya dizer — iptal edilirlerse
/// yerlerini de bırakırlar.
actor RequestThrottle {
    private let interval: Duration
    private var nextSlot: ContinuousClock.Instant = .now

    init(minimumInterval: Duration) {
        interval = minimumInterval
    }

    /// Sıradaki yeri ayırır ve zamanı gelene kadar bekler.
    ///
    /// Yer, uyumadan **önce** ayrılıyor: aksi hâlde aynı anda gelen çağrıların
    /// hepsi aynı boş aralığı görüp birlikte kalkardı.
    func wait() async {
        let now = ContinuousClock.now
        let slot = max(nextSlot, now)
        nextSlot = slot.advanced(by: interval)

        guard slot > now else { return }
        try? await Task.sleep(until: slot, clock: .continuous)
    }
}

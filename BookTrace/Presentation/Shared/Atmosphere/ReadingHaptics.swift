//
//  ReadingHaptics.swift
//  Atmosphere
//
//  Created by Semih TAKILAN on 04.09.2026.
//

import UIKit

/// Uygulamanın dokunsal geri bildirimi.
///
/// Üreteçler tekrar tekrar kurulmuyor: sayfa çarkı sürüklenirken her tıkta yeni
/// bir `UIImpactFeedbackGenerator` yaratmak ilk tıkı geciktiriyordu.
@MainActor
enum ReadingHaptics {
    private static let tick = UISelectionFeedbackGenerator()
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let firm = UIImpactFeedbackGenerator(style: .rigid)
    private static let notice = UINotificationFeedbackGenerator()

    /// Sürükleme sırasında bir birim geçildi.
    static func step() {
        tick.selectionChanged()
        tick.prepare()
    }

    /// Sayaç durdu ya da devam etti.
    static func toggle() {
        soft.impactOccurred(intensity: 0.7)
    }

    /// Bir dönüm noktası geçildi — yarısı, sonu.
    static func milestone() {
        firm.impactOccurred()
    }

    /// Oturum kaydedildi.
    static func saved() {
        notice.notificationOccurred(.success)
    }

    /// Sürükleme başlamadan önce üreteçleri hazırlar.
    static func prepare() {
        tick.prepare()
        soft.prepare()
    }
}

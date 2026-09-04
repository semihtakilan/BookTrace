//
//  ReadingMotion.swift
//  Atmosphere
//
//  Created by Semih TAKILAN on 04.09.2026.
//

import SwiftUI

/// Uygulamanın hareket sözlüğü.
///
/// Süreler tek yerde: aynı jest iki ekranda farklı hızda oynadığında arayüz
/// derli toplu olmaktan çıkıyor.
enum ReadingMotion {
    /// Kart açılması, bölüm değişmesi — gözün takip edebileceği yumuşak geçiş.
    static let gentle = Animation.smooth(duration: 0.42)
    /// Dokunmaya cevap: seçim, filtre, sekme.
    static let snappy = Animation.snappy(duration: 0.26, extraBounce: 0.05)
    /// İlerlemenin dolması — biraz yay, çünkü kazanılmış bir şey.
    static let progress = Animation.spring(response: 0.65, dampingFraction: 0.78)
    /// Kutlama: kitap bitti, dönüm noktası geçildi.
    static let celebrate = Animation.spring(response: 0.55, dampingFraction: 0.6)

    /// Arka plan hareketinin kare hızı. 30 kare/sn ambiyans için yeterli ve
    /// uzun okuma oturumlarında pili tüketmiyor.
    static let ambientFrameInterval: Double = 1.0 / 30.0
}

extension View {
    /// `Reduce Motion` açıkken animasyonu tamamen atlar.
    ///
    /// `.animation(...)` doğrudan kullanıldığında her çağrı yerinde ayrıca
    /// kontrol gerekiyordu; birkaç yerde unutulmuştu.
    func readingAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(ReadingAnimationModifier(animation: animation, value: value))
    }
}

private struct ReadingAnimationModifier<V: Equatable>: ViewModifier {
    let animation: Animation
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

/// Sürekli çalışan dekoratif hareketin açık olup olmadığı.
///
/// `Reduce Motion` dışında düşük güç modunu da dinler: okuma oturumu uzun
/// sürüyor ve pil azaldığında arka planı canlı tutmanın bedeli var.
@propertyWrapper
struct AmbientMotion: DynamicProperty {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    var wrappedValue: Bool { !reduceMotion && !isLowPower }

    /// Güç durumu bildirimi `View` ağacına bağlanabilsin diye.
    var projectedValue: Binding<Bool> {
        Binding(get: { isLowPower }, set: { isLowPower = $0 })
    }
}

extension View {
    /// Düşük güç modu değiştiğinde bağlı değeri tazeler.
    func tracksLowPowerMode(_ isLowPower: Binding<Bool>) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            isLowPower.wrappedValue = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
}

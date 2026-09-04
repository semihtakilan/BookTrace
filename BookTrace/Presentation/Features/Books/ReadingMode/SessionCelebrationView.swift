//
//  SessionCelebrationView.swift
//  ReadingMode
//
//  Created by Semih TAKILAN on 04.09.2026.
//

import SwiftUI

/// Oturum kaydedildikten sonra çıkan kutlama.
///
/// Kendiliğinden kapanır ama dokunulunca da kapanır: kullanıcıyı bir animasyonun
/// bitmesini beklemeye zorlamak, ikinci gösterimde can sıkıcı oluyor.
struct SessionCelebrationView: View {
    let outcome: SessionOutcome
    let onDismiss: () -> Void

    @Environment(\.bookPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()
    @State private var hasAppeared = false

    private var duration: TimeInterval { outcome.isMajor ? 3.2 : 2.4 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()

            if !reduceMotion {
                TimelineView(.animation(minimumInterval: ReadingMotion.ambientFrameInterval)) { context in
                    Canvas { graphics, size in
                        drawBurst(&graphics, size: size,
                                  elapsed: context.date.timeIntervalSince(startDate))
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            card
                .scaleEffect(hasAppeared ? 1 : 0.86)
                .opacity(hasAppeared ? 1 : 0)
        }
        .contentShape(.rect)
        .onTapGesture(perform: onDismiss)
        .task {
            withAnimation(reduceMotion ? nil : ReadingMotion.celebrate) { hasAppeared = true }
            // Kaydetme dokunuşu zaten titriyor; ikinci bir darbe yalnızca
            // kitabın bittiği anda, gerçekten büyük olduğu için.
            if outcome.isMajor { ReadingHaptics.milestone() }
            // `try?` ile yutulan iptal, kutlamayı anında kapatıyordu: görünüm
            // yeniden kurulduğunda görev iptal oluyor, uyku hemen dönüyor ve
            // `onDismiss` daha ilk kare çizilmeden çağrılıyordu.
            do { try await Task.sleep(for: .seconds(duration)) } catch { return }
            onDismiss()
        }
        // Kutlama görsel bir ödül; ekran okuyucu için tek bir duyuru yeterli.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
    }

    private var card: some View {
        VStack(spacing: 18) {
            Image(systemName: outcome.systemImage)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(palette.glow)
                .frame(width: 92, height: 92)
                .background(.white.opacity(0.10), in: .circle)
                .overlay { Circle().strokeBorder(palette.halo.opacity(0.45), lineWidth: 1) }

            VStack(spacing: 10) {
                Text(outcome.title)
                    .font(ReadingStyle.title(.title))
                    .foregroundStyle(.white)
                Text(outcome.message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineSpacing(3)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Text("Tap to continue")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 4)
        }
        .padding(32)
        .frame(maxWidth: 360)
        // Kart yeterince örtücü olmalı: ilk denemede altındaki kapak ve sayaç
        // mesajın içinden okunuyor, iki metin birbirine karışıyordu.
        .background(.black.opacity(0.86), in: .rect(cornerRadius: 30))
        .overlay {
            RoundedRectangle(cornerRadius: 30)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
        .padding(28)
    }

    /// Merkezden dağılıp yerçekimiyle düşen parçacıklar.
    ///
    /// Konumlar zamanın fonksiyonu; saklanan parçacık durumu yok, bu yüzden
    /// yeniden çizim animasyonu bozmuyor.
    private func drawBurst(_ context: inout GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        guard elapsed < duration else { return }

        let count = outcome.isMajor ? 90 : 46
        let center = CGPoint(x: size.width / 2, y: size.height * 0.42)
        let gravity = 520.0
        let colors = [palette.glow, palette.halo, .white, ReadingStyle.gold]

        for index in 0..<count {
            let random = Self.noise(index, 1)
            let angle = (Double(index) / Double(count)) * .pi * 2 + random * 0.4
            let speed = 150 + Self.noise(index, 2) * (outcome.isMajor ? 460 : 300)
            let spin = Self.noise(index, 3) * 12 - 6

            let x = center.x + cos(angle) * speed * elapsed
            let y = center.y + sin(angle) * speed * elapsed + 0.5 * gravity * elapsed * elapsed

            let life = elapsed / duration
            let opacity = max(0, 1 - life * life * 1.4)
            guard opacity > 0.01 else { continue }

            let side = 3 + Self.noise(index, 4) * 5
            let rect = CGRect(x: -side / 2, y: -side / 4, width: side, height: side / 2)
            var shape = Path(roundedRect: rect, cornerRadius: 1)
            shape = shape.applying(
                CGAffineTransform(rotationAngle: spin * elapsed)
                    .concatenating(CGAffineTransform(translationX: x, y: y))
            )
            context.fill(shape, with: .color(colors[index % colors.count].opacity(opacity)))
        }
    }

    private static func noise(_ index: Int, _ salt: Int) -> Double {
        let value = sin(Double(index) * 91.7 + Double(salt) * 47.3) * 43758.5453
        return value - value.rounded(.down)
    }
}

/// Oturum sürerken geçilen dakika eşiği için kısa bir bildirim.
struct SessionMilestoneToast: View {
    let minutes: Int
    @Environment(\.bookPalette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.badge.checkmark")
                .foregroundStyle(palette.glow)
                .accessibilityHidden(true)
            Text(SessionMilestoneCopy.message(minutes: minutes))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.black.opacity(0.45), in: .capsule)
        .overlay { Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1) }
        .padding(.horizontal, 24)
        .shadow(color: .black.opacity(0.3), radius: 14, y: 6)
    }
}

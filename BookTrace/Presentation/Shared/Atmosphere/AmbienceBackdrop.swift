//
//  AmbienceBackdrop.swift
//  Atmosphere
//
//  Created by Semih TAKILAN on 04.09.2026.
//

import Models
import SwiftUI

/// Okuma ekranının arka planı: kitabın rengiyle boyanmış, türüne göre hareket
/// eden bir alan.
///
/// Hareket `Canvas` içinde ve zamanın saf bir fonksiyonu olarak çiziliyor —
/// parçacıkların saklanan bir durumu yok. Böylece duraklatmak, arka plana atıp
/// geri dönmek ve `Reduce Motion` ile tamamen kapatmak ek iş gerektirmiyor;
/// aynı `t` her zaman aynı kareyi veriyor.
struct AmbienceBackdrop: View {
    let ambience: BookAmbience
    let palette: BookPalette
    /// Sayaç duraklatıldığında alan da durur — duraklama görsel olarak da hissedilir.
    var isActive = true

    @Environment(\.colorScheme) private var colorScheme
    @AmbientMotion private var allowsMotion

    var body: some View {
        ZStack {
            LinearGradient(colors: palette.atmosphere(colorScheme),
                           startPoint: .top, endPoint: .bottom)

            TimelineView(.animation(minimumInterval: ReadingMotion.ambientFrameInterval,
                                    paused: !isActive || !allowsMotion)) { context in
                Canvas { graphics, size in
                    // Hareket kapalıyken de alan çizilir, yalnızca zaman durur:
                    // boş bir degrade yerine sabit bir doku kalır.
                    let time = allowsMotion
                        ? context.date.timeIntervalSinceReferenceDate
                        : 0
                    AmbienceField.draw(ambience.field, in: &graphics, size: size, time: time, palette: palette)
                }
            }
            .blendMode(.plusLighter)
            .opacity(0.85)

            // Kenarları koyultmak ortadaki kitabı öne çıkarıyor; degrade tek
            // başına düz duruyordu.
            RadialGradient(colors: [.clear, .black.opacity(0.45)],
                           center: .center, startRadius: 90, endRadius: 460)
        }
        .ignoresSafeArea()
        .tracksLowPowerMode($allowsMotion)
        .accessibilityHidden(true)
    }
}

// MARK: - Alanların çizimi

extension AmbienceField {

    static func draw(_ field: AmbienceField, in context: inout GraphicsContext,
                     size: CGSize, time: TimeInterval, palette: BookPalette) {
        switch field {
        case .motes:  drawDrift(&context, size, time, palette, style: .mote)
        case .sparks: drawDrift(&context, size, time, palette, style: .spark)
        case .leaves: drawDrift(&context, size, time, palette, style: .leaf)
        case .lines:  drawDrift(&context, size, time, palette, style: .line)
        case .stars:  drawStars(&context, size, time, palette)
        case .fog:    drawFog(&context, size, time, palette)
        case .grain:  drawGrain(&context, size, time, palette)
        case .rings:  drawRings(&context, size, time, palette)
        case .grid:   drawGrid(&context, size, time, palette)
        case .lamp:   drawLamp(&context, size, time, palette)
        }
    }

    /// Süzülen parçacıkların dört çeşidi; hepsi aynı hareketi farklı ağırlık,
    /// yön ve biçimle kullanıyor.
    private enum DriftStyle {
        case mote, spark, leaf, line

        var count: Int {
            switch self {
            case .mote: 34
            case .spark: 26
            case .leaf: 18
            case .line: 22
            }
        }

        /// Saniyede kaç nokta yol alındığı. Eksi değer yukarı doğrudur.
        var speed: Double {
            switch self {
            case .mote: -14
            case .spark: -22
            case .leaf: 26
            case .line: -34
            }
        }

        var opacity: Double {
            switch self {
            case .mote: 0.42
            case .spark: 0.75
            case .leaf: 0.5
            case .line: 0.36
            }
        }
    }

    private static func drawDrift(_ context: inout GraphicsContext, _ size: CGSize,
                                  _ time: TimeInterval, _ palette: BookPalette, style: DriftStyle) {
        let span = size.height + 120
        let glow = palette.glow

        for index in 0..<style.count {
            let seedX = noise(index, 1)
            let seedPhase = noise(index, 2) * .pi * 2
            let seedSize = 1.4 + noise(index, 3) * 3.2
            let seedDepth = 0.45 + noise(index, 4) * 0.55

            let travelled = (noise(index, 5) * span + time * style.speed * seedDepth)
            let y = travelled.truncatingRemainder(dividingBy: span)
            let wrappedY = (y < 0 ? y + span : y) - 60

            let wobble = sin(time * 0.35 * seedDepth + seedPhase) * (12 + seedSize * 4)
            let x = seedX * size.width + wobble

            let twinkle = 0.55 + 0.45 * sin(time * 0.8 + seedPhase)
            let fade = min(1, min(wrappedY + 60, span - wrappedY) / 90)
            let opacity = style.opacity * seedDepth * twinkle * max(0, fade)

            switch style {
            case .line:
                var path = Path()
                path.move(to: CGPoint(x: x, y: wrappedY))
                path.addLine(to: CGPoint(x: x, y: wrappedY + seedSize * 9))
                context.stroke(path, with: .color(glow.opacity(opacity)), lineWidth: 0.9)

            case .leaf:
                let rect = CGRect(x: x, y: wrappedY, width: seedSize * 3.4, height: seedSize * 1.6)
                var leaf = Path(ellipseIn: rect)
                leaf = leaf.applying(
                    CGAffineTransform(translationX: -rect.midX, y: -rect.midY)
                        .concatenating(CGAffineTransform(rotationAngle: time * 0.6 + seedPhase))
                        .concatenating(CGAffineTransform(translationX: rect.midX, y: rect.midY))
                )
                context.fill(leaf, with: .color(glow.opacity(opacity)))

            case .mote, .spark:
                let diameter = seedSize * (style == .spark ? 1.5 : 1.1)
                let rect = CGRect(x: x, y: wrappedY, width: diameter, height: diameter)
                context.fill(Path(ellipseIn: rect), with: .color(glow.opacity(opacity)))
                if style == .spark {
                    context.fill(
                        Path(ellipseIn: rect.insetBy(dx: -diameter * 1.6, dy: -diameter * 1.6)),
                        with: .color(glow.opacity(opacity * 0.18))
                    )
                }
            }
        }
    }

    private static func drawStars(_ context: inout GraphicsContext, _ size: CGSize,
                                  _ time: TimeInterval, _ palette: BookPalette) {
        // Önce iki bulutsu; yıldızlar bunların üstünde parlıyor.
        for index in 0..<2 {
            let phase = time * 0.02 + Double(index) * 2.1
            let center = CGPoint(x: size.width * (0.3 + 0.4 * Double(index)) + sin(phase) * 40,
                                 y: size.height * (0.3 + 0.35 * Double(index)) + cos(phase * 0.8) * 30)
            let radius = min(size.width, size.height) * 0.55
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                       width: radius * 2, height: radius * 2)),
                with: .radialGradient(
                    Gradient(colors: [palette.halo.opacity(0.20), .clear]),
                    center: center, startRadius: 0, endRadius: radius
                )
            )
        }

        // Üç derinlik katmanı: uzaktakiler yavaş ve sönük.
        for layer in 0..<3 {
            let depth = Double(layer + 1) / 3
            let drift = time * (3 + Double(layer) * 7)
            for index in 0..<26 {
                let seed = layer * 100 + index
                let x = (noise(seed, 1) * size.width + drift)
                    .truncatingRemainder(dividingBy: size.width)
                let y = noise(seed, 2) * size.height
                let radius = 0.6 + depth * 1.5
                let twinkle = 0.4 + 0.6 * abs(sin(time * (0.6 + depth) + noise(seed, 3) * 6))
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
                    with: .color(.white.opacity(0.16 + 0.5 * depth * twinkle))
                )
            }
        }
    }

    private static func drawFog(_ context: inout GraphicsContext, _ size: CGSize,
                                _ time: TimeInterval, _ palette: BookPalette) {
        for index in 0..<5 {
            let phase = Double(index) * 1.7
            let speed = 0.035 + Double(index) * 0.012
            let x = size.width * (0.5 + 0.55 * sin(time * speed + phase))
            let y = size.height * (0.25 + 0.5 * Double(index) / 4) + cos(time * speed * 1.3 + phase) * 26
            let radius = size.width * (0.35 + 0.18 * noise(index, 7))

            context.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius * 0.55,
                                       width: radius * 2, height: radius * 1.1)),
                with: .radialGradient(
                    Gradient(colors: [palette.halo.opacity(0.16), .clear]),
                    center: CGPoint(x: x, y: y), startRadius: 0, endRadius: radius
                )
            )
        }
    }

    private static func drawGrain(_ context: inout GraphicsContext, _ size: CGSize,
                                  _ time: TimeInterval, _ palette: BookPalette) {
        // Kâğıt dokusu sabit durur; yalnızca üstünden geçen ışık hareket eder.
        for index in 0..<150 {
            let x = noise(index, 11) * size.width
            let y = noise(index, 12) * size.height
            let radius = 0.5 + noise(index, 13) * 1.1
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                with: .color(palette.glow.opacity(0.10 + noise(index, 14) * 0.14))
            )
        }

        let sweep = (time * 0.05).truncatingRemainder(dividingBy: 2) - 0.5
        let bandCenter = size.height * sweep
        context.fill(
            Path(CGRect(x: 0, y: bandCenter - size.height * 0.3,
                        width: size.width, height: size.height * 0.6)),
            with: .linearGradient(
                Gradient(colors: [.clear, palette.glow.opacity(0.10), .clear]),
                startPoint: CGPoint(x: 0, y: bandCenter - size.height * 0.3),
                endPoint: CGPoint(x: size.width, y: bandCenter + size.height * 0.3)
            )
        )
    }

    private static func drawRings(_ context: inout GraphicsContext, _ size: CGSize,
                                  _ time: TimeInterval, _ palette: BookPalette) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.44)
        let maximum = max(size.width, size.height) * 0.75

        for index in 0..<7 {
            let phase = Double(index) * 0.55
            // Nefes ritmi: dört saniyede bir dolup boşalıyor.
            let breath = 0.5 + 0.5 * sin(time * 0.5 - phase)
            let radius = maximum * (0.14 + 0.12 * Double(index)) * (0.92 + breath * 0.14)
            let opacity = (0.30 - Double(index) * 0.033) * (0.55 + breath * 0.45)

            context.stroke(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                       width: radius * 2, height: radius * 2)),
                with: .color(palette.glow.opacity(max(0, opacity))),
                lineWidth: 1.1
            )
        }
    }

    private static func drawGrid(_ context: inout GraphicsContext, _ size: CGSize,
                                 _ time: TimeInterval, _ palette: BookPalette) {
        let line = palette.glow.opacity(0.14)

        for index in 0..<11 {
            let x = size.width * Double(index) / 10
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(line), lineWidth: 0.6)
        }

        // Yatay çizgiler aşağı indikçe seyrekleşir; ufuk hissi bundan geliyor.
        let offset = (time * 0.06).truncatingRemainder(dividingBy: 1)
        for index in 0..<14 {
            let progress = (Double(index) + offset) / 14
            let y = size.height * progress * progress
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(palette.glow.opacity(0.05 + progress * 0.12)), lineWidth: 0.6)
        }

        let scan = size.height * ((time * 0.08).truncatingRemainder(dividingBy: 1))
        context.fill(
            Path(CGRect(x: 0, y: scan - 40, width: size.width, height: 80)),
            with: .linearGradient(
                Gradient(colors: [.clear, palette.glow.opacity(0.16), .clear]),
                startPoint: CGPoint(x: 0, y: scan - 40),
                endPoint: CGPoint(x: 0, y: scan + 40)
            )
        )
    }

    private static func drawLamp(_ context: inout GraphicsContext, _ size: CGSize,
                                 _ time: TimeInterval, _ palette: BookPalette) {
        // Lissajous yolu: ışık aynı yere iki kez aynı açıdan gelmiyor.
        let center = CGPoint(x: size.width * (0.5 + 0.28 * sin(time * 0.06)),
                             y: size.height * (0.38 + 0.18 * sin(time * 0.043 + 1.2)))
        let radius = min(size.width, size.height) * 0.85

        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                   width: radius * 2, height: radius * 2)),
            with: .radialGradient(
                Gradient(colors: [palette.halo.opacity(0.30), palette.halo.opacity(0.06), .clear]),
                center: center, startRadius: 0, endRadius: radius
            )
        )
    }

    /// Konumları ve fazları üreten sözde-rastgele değer.
    ///
    /// `Double.random` kullanılamaz: alan zamanın saf bir fonksiyonu olmalı ki
    /// duraklatıp devam ettirmek parçacıkları yerinden oynatmasın.
    private static func noise(_ index: Int, _ salt: Int) -> Double {
        let value = sin(Double(index) * 127.1 + Double(salt) * 311.7) * 43758.5453
        return value - value.rounded(.down)
    }
}

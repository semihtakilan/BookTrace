//
//  PageDial.swift
//  ReadingMode
//
//  Created by Semih TAKILAN on 04.09.2026.
//

import SwiftUI

/// Okunan sayfa sayısını sürükleyerek seçtiren cetvel.
///
/// Önceden burada sayı klavyesi vardı. Oturumun en güzel anında ekranın yarısını
/// kaplayan bir klavye açmak akışı bozuyordu; üstelik girilen değer çoğu zaman
/// tek haneli. Cetvel tek başparmakla, telefona bakmadan da çevrilebiliyor ve
/// her sayfada bir tık veriyor.
///
/// Kesin bir sayı yazmak isteyenler için rakamın kendisi hâlâ dokunulabilir.
struct PageDial: View {
    @Binding var pages: Int
    let maximum: Int
    let tint: Color

    @State private var scrollTarget: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let tickSpacing: CGFloat = 14
    private var upperBound: Int { max(0, min(maximum, 2000)) }

    var body: some View {
        VStack(spacing: 14) {
            ruler
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pages read")
        .accessibilityValue("\(pages)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: pages = min(upperBound, pages + 1)
            case .decrement: pages = max(0, pages - 1)
            @unknown default: break
            }
        }
    }

    private var ruler: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(0...upperBound, id: \.self) { value in
                        tick(value)
                            .frame(width: tickSpacing)
                            .id(value)
                    }
                }
                .scrollTargetLayout()
            }
            // `.never`: varsayılan davranış her kaydırmada tek bir çentik
            // ilerletiyor, 300 sayfalık bir kitapta cetvel kullanılmaz oluyordu.
            .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
            .scrollPosition(id: $scrollTarget, anchor: .center)
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, max(0, (geometry.size.width - tickSpacing) / 2), for: .scrollContent)
            .mask {
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.12),
                    .init(color: .black, location: 0.88),
                    .init(color: .clear, location: 1)
                ], startPoint: .leading, endPoint: .trailing)
            }
        }
        .frame(height: 64)
        // Cetvel çıplak çizgilerken bir denetim gibi durmuyordu; hafif bir
        // zemin onu "çevrilebilir" bir şeye dönüştürüyor.
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.10), lineWidth: 1) }
        .overlay(alignment: .center) { needle }
        .onAppear { scrollTarget = pages }
        .onChange(of: scrollTarget) { previous, current in
            guard let current, current != pages else { return }
            pages = current
            if previous != nil { ReadingHaptics.step() }
        }
        .onChange(of: pages) { _, current in
            // Rakam elle yazıldığında cetvel de oraya gider.
            guard scrollTarget != current else { return }
            withAnimation(reduceMotion ? nil : ReadingMotion.snappy) { scrollTarget = current }
        }
    }

    private func tick(_ value: Int) -> some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(.white.opacity(value.isMultiple(of: 10) ? 0.55 : 0.24))
                .frame(width: value.isMultiple(of: 10) ? 2 : 1.2,
                       height: value.isMultiple(of: 10) ? 26 : (value.isMultiple(of: 5) ? 18 : 11))
                .frame(height: 30, alignment: .top)

            if value.isMultiple(of: 10) {
                Text(value, format: .number)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.42))
                    .fixedSize()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var needle: some View {
        VStack(spacing: 0) {
            Triangle()
                .fill(tint)
                .frame(width: 12, height: 7)
            Capsule()
                .fill(tint)
                .frame(width: 2.5, height: 30)
            Spacer(minLength: 0)
        }
        .frame(height: 64, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

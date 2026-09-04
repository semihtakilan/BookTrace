//
//  BookVolumeView.swift
//  Atmosphere
//
//  Created by Semih TAKILAN on 04.09.2026.
//

import Models
import SwiftUI

/// Kapağı düz bir dikdörtgen yerine gerçek bir cilt gibi gösterir: sırt gölgesi,
/// sağ kenarda sayfa bloğu, üstünde ilerlemeyi gösteren bir ayraç.
///
/// Ayraç bilinçli olarak yüzde yazısının yerine geçmiyor, onun yanında duruyor —
/// rakamı okumadan da kitabın neresinde olduğun görülüyor.
struct BookVolumeView: View {
    let book: BookReference
    var height: CGFloat
    /// 0...1. `nil` ise ayraç çizilmez (kütüphanede olmayan kitaplar).
    var progress: Double?
    /// Kitabı hafifçe salındırır — yalnızca okuma ekranında açık.
    var isFloating = false

    @Environment(\.bookPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @AmbientMotion private var allowsMotion

    private var width: CGFloat { height * 2 / 3 }
    private var pageBlockWidth: CGFloat { max(3, height * 0.028) }

    /// Verilen toplam genişliğe (kapak + sayfa bloğu) sığan yükseklik.
    ///
    /// Izgaralarda sütun genişliği belli, yükseklik değil. Hesabı burada
    /// tutmak, oranın çağıran her yerde elle tekrarlanmasını önlüyor.
    static func height(fittingWidth width: CGFloat) -> CGFloat {
        let proportional = width / (2.0 / 3.0 + 0.028)
        // Küçük boyutlarda sayfa bloğu 3 pt'de sabitleniyor; oran orada geçersiz.
        return proportional * 0.028 >= 3 ? proportional : max(1, width - 3) * 1.5
    }

    var body: some View {
        volume
            .modifier(FloatingTilt(isEnabled: isFloating && allowsMotion))
            .tracksLowPowerMode($allowsMotion)
            .accessibilityHidden(true)
    }

    private var volume: some View {
        ZStack(alignment: .topLeading) {
            pageBlock
                .offset(x: width - 1)

            RemoteBookCover(
                url: book.coverURL,
                width: width,
                height: height,
                contentMode: .fill,
                fallbackTitle: book.title,
                fallbackAuthor: book.author,
                shape: AnyShape(BookShape())
            )
            .overlay { spine }
            .overlay { edgeLight }
            .clipShape(BookShape())

            // Ayraç okunmuş bir kitabın işareti; hiç açılmamış bir kitapta
            // kapağın üstünde duran anlamsız bir şerit oluyordu.
            if let progress, progress > 0 {
                bookmark(progress: progress)
            }
        }
        .frame(width: width + pageBlockWidth, height: height, alignment: .topLeading)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.55 : 0.28),
                radius: height * 0.09, x: height * 0.02, y: height * 0.055)
    }

    /// Sağ kenarda üst üste duran sayfalar.
    private var pageBlock: some View {
        ZStack(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                   bottomTrailingRadius: 3, topTrailingRadius: 3)
                .fill(LinearGradient(
                    colors: [Color(white: 0.82), Color(white: 0.96), Color(white: 0.78)],
                    startPoint: .leading, endPoint: .trailing
                ))

            // Tek tek sayfa çizgileri: blok tek renk olduğunda plastik görünüyordu.
            HStack(spacing: 0) {
                ForEach(0..<Int(max(2, pageBlockWidth)), id: \.self) { index in
                    Rectangle()
                        .fill(.black.opacity(index.isMultiple(of: 2) ? 0.08 : 0.0))
                        .frame(width: 1)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(width: pageBlockWidth, height: height - height * 0.012)
        .offset(y: height * 0.006)
    }

    /// Sol kenardaki cilt katlanması.
    private var spine: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [.black.opacity(0.42), .black.opacity(0.06), .white.opacity(0.14), .clear],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: width * 0.13)
            Spacer(minLength: 0)
        }
    }

    /// Üstten gelen ışığın kapakta bıraktığı ince parlaklık.
    private var edgeLight: some View {
        LinearGradient(
            colors: [.white.opacity(0.16), .clear, .black.opacity(0.14)],
            startPoint: .top, endPoint: .bottom
        )
        .blendMode(.overlay)
    }

    private func bookmark(progress: Double) -> some View {
        let clamped = min(max(progress, 0), 1)
        // Ayraç hiç görünmez olmasın: yeni başlanmış bir kitapta da uçtan
        // birkaç nokta sarkar.
        let length = height * (0.22 + 0.7 * clamped)
        let ribbonWidth = max(7, width * 0.11)

        // Renk her iki temada da koyu vurgudan parlak haleye gider: ayraç,
        // altındaki kapak ne renk olursa olsun ondan ayrılmalı. Temaya bağlı
        // seçildiğinde açık temada soluk kapakların üstünde kayboluyordu.
        return BookmarkShape()
            .fill(LinearGradient(colors: [palette.accent(.light), palette.halo],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .leading) {
                // Katlanma çizgisi; şeridi düz bir dikdörtgen olmaktan çıkarıyor.
                Rectangle().fill(.white.opacity(0.35)).frame(width: 1)
            }
            .frame(width: ribbonWidth, height: length)
            .shadow(color: .black.opacity(0.35), radius: 3, x: 1, y: 2)
            .offset(x: width * 0.78, y: -height * 0.045)
            .readingAnimation(ReadingMotion.progress, value: clamped)
    }
}

/// Kitabın kendi köşe yuvarlaması: sırt tarafı keskin, dış kenar yumuşak.
private struct BookShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) * 0.045
        return UnevenRoundedRectangle(
            topLeadingRadius: 2,
            bottomLeadingRadius: 2,
            bottomTrailingRadius: radius,
            topTrailingRadius: radius
        )
        .path(in: rect)
    }
}

/// Ucu çentikli ayraç.
private struct BookmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let notch = rect.width * 0.55
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - notch))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Kitabı çok yavaş salındırır.
///
/// Süre değil zaman tabanlı: ekran arka plandan döndüğünde animasyon baştan
/// başlamıyor, kaldığı yerden devam ediyor.
private struct FloatingTilt: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            TimelineView(.animation(minimumInterval: ReadingMotion.ambientFrameInterval)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                content
                    .rotation3DEffect(.degrees(sin(time * 0.25) * 6),
                                      axis: (x: 0, y: 1, z: 0), perspective: 0.45)
                    .rotation3DEffect(.degrees(sin(time * 0.19 + 1) * 2.2),
                                      axis: (x: 1, y: 0, z: 0), perspective: 0.45)
                    .offset(y: sin(time * 0.31) * 4)
            }
        } else {
            content
        }
    }
}

//
//  TintedProgressBar.swift
//  Atmosphere
//
//  Created by Semih TAKILAN on 04.09.2026.
//

import SwiftUI

/// Kitabın kendi rengiyle dolan ince ilerleme çubuğu.
///
/// `ProgressView(value:)` yerine elle çiziliyor: sistem çubuğu tek renk ve sabit
/// kalınlıkta, üstelik dolum animasyonunu bastırıyor. Burada dolum yayla
/// oturuyor — sayfa kaydedildiğinde çubuğun ilerlediği gerçekten görülüyor.
struct TintedProgressBar: View {
    let fraction: Double
    let tint: Color
    var track: Color = .primary.opacity(0.10)
    var height: CGFloat = 7

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.75), tint],
                                         startPoint: .leading, endPoint: .trailing))
                    // Sıfırın hemen üstündeki ilerleme de görünsün diye en az
                    // bir yuvarlak uç kadar genişlik ayrılıyor.
                    .frame(width: fraction <= 0 ? 0 : max(height, geometry.size.width * min(1, fraction)))
            }
            .readingAnimation(ReadingMotion.progress, value: fraction)
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

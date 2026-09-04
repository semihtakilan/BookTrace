//
//  BookHeroHeader.swift
//  Atmosphere
//
//  Created by Semih TAKILAN on 04.09.2026.
//

import Models
import SwiftUI

/// Kitap ekranlarının açılışı: kapağın kendisi ekranın rengini veriyor.
///
/// Eskiden kapak, sabit açık yeşil bir kutunun ortasında duran 142 pt'lik bir
/// küçük resimdi ve her kitap birbirinin aynıydı. Burada kapağın bulanık bir
/// büyütmesi zemin oluyor, keskin kopyası önünde duruyor — kitabın kimliği
/// ekranın kimliği hâline geliyor.
struct BookHeroHeader: View {
    let book: BookReference
    /// Kütüphanedeki kitaplarda ayracı çizmek için.
    var progress: Double?

    @Environment(\.bookPalette) private var palette
    @Environment(\.bookAmbience) private var ambience
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var coverHeight: CGFloat { dynamicTypeSize.isAccessibilitySize ? 150 : 196 }

    var body: some View {
        VStack(spacing: 18) {
            BookVolumeView(book: book, height: coverHeight, progress: progress)
                .padding(.top, 18)

            VStack(spacing: 8) {
                Text(book.title)
                    .font(ReadingStyle.title(.title))
                    .foregroundStyle(ReadingStyle.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                if !book.author.isEmpty {
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundStyle(ReadingStyle.secondary)
                }

                facts
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.bottom, 26)
        .background(alignment: .top) { backdrop }
    }

    /// Sayfa sayısı, yıl ve tür — üç küçük etiket hâlinde.
    private var facts: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))

        return layout {
            if let count = book.pageCount, count > 0 {
                fact(Text("\(count) pages"))
            }
            if let year = book.publicationYear {
                fact(Text(verbatim: year))
            }
            fact(Text(ambience.roomName))
        }
        .padding(.top, 6)
    }

    private func fact(_ text: Text) -> some View {
        text
            .font(.caption2.weight(.medium))
            .foregroundStyle(palette.accent(colorScheme))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(palette.accent(colorScheme).opacity(0.12), in: .capsule)
    }

    /// Kapağın bulanık büyütmesi. Kapak yoksa `RemoteBookCover` kendi yedeğini
    /// çiziyor, yani zemin yine kitaba ait bir şey oluyor.
    private var backdrop: some View {
        GeometryReader { geometry in
            RemoteBookCover(
                url: book.coverURL,
                width: geometry.size.width,
                height: geometry.size.height,
                contentMode: .fill,
                fallbackTitle: book.title,
                fallbackAuthor: book.author,
                shape: AnyShape(Rectangle())
            )
            .blur(radius: 44, opaque: true)
            .overlay {
                LinearGradient(
                    colors: [ReadingStyle.background.opacity(0.55),
                             ReadingStyle.background.opacity(0.86),
                             ReadingStyle.background],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .overlay(alignment: .top) {
                // Üstteki gezinme çubuğunun altında kalan şerit fazla canlı
                // kalıyordu; başlık okunur kalsın diye ayrıca koyultuluyor.
                LinearGradient(colors: [ReadingStyle.background, .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 40)
            }
        }
        .accessibilityHidden(true)
    }
}

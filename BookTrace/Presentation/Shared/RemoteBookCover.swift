//
//  RemoteBookCover.swift
//  Shared
//
//  Created by Semih TAKILAN on 06.08.2026.
//

import Kingfisher
import SwiftUI

/// Kitap kapağı. Kapak yoksa veya indirilemezse başlık ve yazardan bir sırt tasarımı üretir.
struct RemoteBookCover: View {
    let url: URL?
    let width: CGFloat?
    let height: CGFloat
    let contentMode: SwiftUI.ContentMode
    let fallbackTitle: String?
    let fallbackAuthor: String?
    /// Kapağın kırpıldığı biçim. `BookVolumeView` sırt tarafı keskin, dış kenarı
    /// yuvarlak kendi biçimini veriyor.
    let shape: AnyShape

    init(
        url: URL?,
        width: CGFloat? = nil,
        height: CGFloat,
        contentMode: SwiftUI.ContentMode,
        fallbackTitle: String? = nil,
        fallbackAuthor: String? = nil,
        shape: AnyShape = AnyShape(RoundedRectangle(cornerRadius: 6))
    ) {
        self.url = url
        self.width = width
        self.height = height
        self.contentMode = contentMode
        self.fallbackTitle = fallbackTitle
        self.fallbackAuthor = fallbackAuthor
        self.shape = shape
    }

    var body: some View {
        Group {
            if let url {
                // Kingfisher indirme sırasında ve hata durumunda placeholder'ı gösterir.
                KFImage(url)
                    .placeholder { fallbackView.frame(width: width, height: height) }
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                fallbackView
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .clipShape(shape)
        // Kapak dekoratif: başlık ve yazar her kullanım yerinde zaten metin
        // olarak yanında duruyor. Görsel yedeği de aynı metni çizdiği için
        // gizlenmezse VoiceOver başlığı iki kez okur.
        .accessibilityHidden(true)
    }

    private var fallbackView: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.25, green: 0.37, blue: 0.30), Color(red: 0.13, green: 0.24, blue: 0.19)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 6) {
                if let fallbackTitle {
                    Text(fallbackTitle)
                        .font(.system(size: height > 150 ? 15 : 11, weight: .bold, design: .serif))
                        .lineLimit(4)
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: height > 150 ? 40 : 24))
                        .foregroundStyle(.white.opacity(0.7))
                }

                if let fallbackAuthor, !fallbackAuthor.isEmpty {
                    Text(fallbackAuthor)
                        .font(.system(size: height > 150 ? 11 : 9, weight: .medium, design: .serif))
                        .lineLimit(2)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .multilineTextAlignment(.center)
            .padding(8)

            // Sırt etkisi: sol kenarda ince bir gölge şeridi.
            HStack {
                Rectangle()
                    .fill(.black.opacity(0.12))
                    .frame(width: 4)
                Spacer(minLength: 0)
            }
        }
    }
}

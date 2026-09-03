//
//  BookCoverCell.swift
//  Shared
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import SwiftUI

/// Yatay raflarda kullanılan kapak + başlık hücresi.
struct BookCoverCell: View {
    let title: String
    let author: String
    let coverURL: URL?
    /// Sabit genişlik erişilebilirlik punto boyutlarında başlığı kesiyordu;
    /// hücre metinle birlikte büyür.
    @ScaledMetric(relativeTo: .caption) var width: CGFloat = 116

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            RemoteBookCover(
                url: coverURL,
                width: width,
                height: width * 1.5,
                contentMode: .fit,
                fallbackTitle: title,
                fallbackAuthor: author
            )
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 4)

            Text(title)
                .font(.system(.subheadline, design: .serif, weight: .medium))
                .lineLimit(3, reservesSpace: true)
                .foregroundStyle(ReadingStyle.ink)

            if !author.isEmpty {
                Text(author)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(ReadingStyle.secondary)
            }
        }
        .frame(width: width, alignment: .leading)
        // Kapak, başlık ve yazar tek bir öğe olarak okunur; aksi hâlde
        // VoiceOver her rafı parça parça geziyor.
        .accessibilityElement(children: .combine)
    }
}

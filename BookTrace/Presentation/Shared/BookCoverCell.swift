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
    @ScaledMetric(relativeTo: .caption) var width: CGFloat = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteBookCover(
                url: coverURL,
                width: width,
                height: width * 1.5,
                contentMode: .fill,
                fallbackTitle: title,
                fallbackAuthor: author
            )

            Text(title)
                .font(.caption.bold())
                .lineLimit(2)
                .foregroundStyle(.primary)

            if !author.isEmpty {
                Text(author)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: width, alignment: .leading)
        // Kapak, başlık ve yazar tek bir öğe olarak okunur; aksi hâlde
        // VoiceOver her rafı parça parça geziyor.
        .accessibilityElement(children: .combine)
    }
}

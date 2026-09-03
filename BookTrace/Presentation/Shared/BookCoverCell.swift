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
    var width: CGFloat = 136
    private var coverWidth: CGFloat { min(124, width - 24) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            RemoteBookCover(
                url: coverURL,
                width: coverWidth,
                height: coverWidth * 1.5,
                contentMode: .fit,
                fallbackTitle: title,
                fallbackAuthor: author
            )
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 4)
            .frame(width: width, height: coverWidth * 1.5 + 24)
            .background(ReadingStyle.sage.opacity(0.55), in: .rect(cornerRadius: 14))

            Text(title)
                .font(.system(.subheadline, design: .serif, weight: .medium))
                .modifier(BookTextLines(count: 3))
                .foregroundStyle(ReadingStyle.ink)

            if !author.isEmpty {
                Text(author)
                    .font(.caption2)
                    .modifier(BookTextLines(count: 2))
                    .foregroundStyle(ReadingStyle.secondary)
            }
        }
        .frame(width: width, alignment: .leading)
        // Kapak, başlık ve yazar tek bir öğe olarak okunur; aksi hâlde
        // VoiceOver her rafı parça parça geziyor.
        .accessibilityElement(children: .combine)
    }
}

/// Align adjacent cards at standard sizes, while allowing complete titles at accessibility sizes.
struct BookTextLines: ViewModifier {
    let count: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            content.fixedSize(horizontal: false, vertical: true)
        } else {
            content.lineLimit(count, reservesSpace: true)
        }
    }
}

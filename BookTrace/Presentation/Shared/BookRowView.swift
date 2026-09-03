//
//  BookRowView.swift
//  Shared
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import SwiftUI

/// Dikey listelerde kullanılan satır: kapak, başlık, yazar ve isteğe bağlı bir alt bilgi.
struct BookRowView: View {
    let title: String
    let author: String
    let coverURL: URL?
    var subtitle: String?

    var body: some View {
        HStack(spacing: 16) {
            RemoteBookCover(
                url: coverURL,
                width: 56,
                height: 84,
                contentMode: .fit,
                fallbackTitle: title,
                fallbackAuthor: author
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.headline, design: .serif))
                    .lineLimit(3)
                    .foregroundStyle(ReadingStyle.ink)

                if !author.isEmpty {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(ReadingStyle.secondary)
                        .lineLimit(1)
                }

                if let subtitle {
                    // `.tertiary` açık temada WCAG AA sınırının altına düşüyordu.
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(ReadingStyle.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

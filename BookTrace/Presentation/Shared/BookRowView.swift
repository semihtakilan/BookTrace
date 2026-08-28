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
                contentMode: .fill,
                fallbackTitle: title,
                fallbackAuthor: author
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                if !author.isEmpty {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .contentShape(.rect)
    }
}

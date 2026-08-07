//
//  BookDetailView.swift
//  BookTrace
//
//  Created by Semih TAKILAN on 3.08.2026.
//

import SwiftUI
import Models

struct BookDetailView: View {
    let book: Book

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                RemoteBookCover(
                    url: book.coverURL,
                    height: 220,
                    contentMode: .fit,
                    fallbackTitle: book.title,
                    fallbackAuthor: book.author
                )

                Text(book.title)
                    .font(.title.bold())

                if !book.authors.isEmpty {
                    Text(book.authors.joined(separator: ", "))
                        .foregroundStyle(.secondary)
                }

                extraContent
            }
            .padding()
        }
    }

    @ViewBuilder
    private var extraContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let date = book.publishedDate {
                Text("Yayın Tarihi: \(date)")
                    .font(.subheadline)
            }
            if let pageCount = book.pageCount {
                Text("\(pageCount) sayfa")
                    .font(.subheadline)
            }
            if let description = book.description {
                Text(description)
                    .font(.body)
            }
        }
    }
}

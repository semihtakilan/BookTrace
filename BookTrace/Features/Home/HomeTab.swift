//
//  HomeTab.swift
//  BookTrace
//
//  Created by Batuhan Baran on 30.07.2026.
//

import SwiftUI
import NavigatorUI
import Models

struct HomeTab: View {
    var body: some View {
        ManagedNavigationStack {
            HomeContentView()
        }
    }
}

private struct HomeContentView: View {
    @Environment(\.navigator)
    private var navigator

    @State private var viewModel = HomeViewModel()

    var body: some View {
        content
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
        case .loaded(let categories):
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(categories) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category.displayName)
                                .font(.title3.bold())
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(category.books) { book in
                                        Button {
                                            navigator.navigate(to: HomeDestinations.bookDetail(book))
                                        } label: {
                                            BookCoverCell(book: book)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
        case .failed(let message):
            ContentUnavailableView {
                Label("Kitaplar Yüklenemedi", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Tekrar Dene") {
                    Task { await viewModel.load() }
                }
            }
        }
    }
}

private struct BookCoverCell: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RemoteBookCover(url: book.coverURL, width: 100, height: 150, contentMode: .fill)

            Text(book.title)
                .font(.caption.bold())
                .lineLimit(2)
                .frame(width: 100, alignment: .leading)
        }
    }
}

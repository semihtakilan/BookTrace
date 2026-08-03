//
//  BookDetailView.swift
//  BookTrace
//
//  Created by Semih TAKILAN on 3.08.2026.
//

import SwiftUI
import Models

struct BookDetailView: View {
    @State private var viewModel: BookDetailViewModel

    init(reference: BookReference) {
        _viewModel = State(initialValue: BookDetailViewModel(reference: reference))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                AsyncImage(url: viewModel.reference.coverURL) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(height: 220)

                Text(viewModel.reference.title)
                    .font(.title.bold())

                if let author = viewModel.reference.authorName {
                    Text(author)
                        .foregroundStyle(.secondary)
                }

                extraContent
            }
            .padding()
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var extraContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
        case .loaded(let detail):
            VStack(alignment: .leading, spacing: 8) {
                if let date = detail.firstPublishDate {
                    Text("İlk Basım: \(date)")
                        .font(.subheadline)
                }
                if let description = detail.description {
                    Text(description)
                        .font(.body)
                }
                if let subjects = detail.subjects, !subjects.isEmpty {
                    Text("Konular: \(subjects.prefix(5).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .failed(let message):
            Text("Ek bilgiler yüklenemedi: \(message)")
                .foregroundStyle(.red)
                .font(.caption)
        }
    }
}

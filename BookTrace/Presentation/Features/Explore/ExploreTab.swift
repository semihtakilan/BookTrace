//
//  ExploreTab.swift
//  Explore
//
//  Created by Semih TAKILAN on 11.08.2026.
//

import SwiftUI
import NavigatorUI
import Models

struct ExploreTab: View {
    private let viewModel: ExploreViewModel

    init(viewModel: ExploreViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ManagedNavigationStack {
            ExploreContentView(viewModel: viewModel)
        }
    }
}

private struct ExploreContentView: View {
    @Bindable var viewModel: ExploreViewModel

    @Environment(\.navigator) private var navigator
    @State private var isPresentingScanner = false

    var body: some View {
        Group {
            if viewModel.isShowingSearchResults {
                searchResults
            } else {
                subjectShelves
            }
        }
        .navigationTitle("Explore")
        .searchable(text: $viewModel.searchText, prompt: "Title, author or ISBN")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingScanner = true
                } label: {
                    Image(systemName: "barcode.viewfinder")
                }
                .accessibilityLabel("Scan barcode")
            }
        }
        // Yazma durduktan yarım saniye sonra arama yapılır; her tuşta ağa çıkılmaz.
        .task(id: viewModel.searchText) {
            guard viewModel.isShowingSearchResults else {
                viewModel.clearSearch()
                return
            }
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return // Metin değişti, bu arama iptal edildi.
            }
            await viewModel.performSearch()
        }
        .task {
            await viewModel.loadShelvesIfNeeded()
        }
        .sheet(isPresented: $isPresentingScanner) {
            scannerSheet
        }
        .onChange(of: viewModel.scannedBook) { _, book in
            guard let book else { return }
            viewModel.scannedBook = nil
            navigator.navigate(to: ExploreDestinations.bookDetail(book))
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            ),
            actions: { Button("OK", role: .cancel) { viewModel.errorMessage = nil } },
            message: { Text(viewModel.errorMessage ?? "") }
        )
    }

    // MARK: - Arama sonuçları

    @ViewBuilder
    private var searchResults: some View {
        switch viewModel.searchState {
        case .idle, .loading:
            ProgressView("Searching…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView(
                "Search failed",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        case .loaded(let books) where books.isEmpty:
            ContentUnavailableView.search(text: viewModel.searchText)
        case .loaded(let books):
            List(books) { book in
                Button {
                    navigator.navigate(to: ExploreDestinations.bookDetail(book))
                } label: {
                    BookRowView(
                        title: book.title,
                        author: book.author,
                        coverURL: book.coverURL,
                        subtitle: book.publicationYear
                    )
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Kategori rafları

    private var subjectShelves: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(viewModel.shelves) { shelf in
                    SubjectShelfRow(shelf: shelf) {
                        await viewModel.retry(shelf: shelf)
                    }
                }
            }
            .padding(.vertical)
        }
    }

    private var scannerSheet: some View {
        NavigationStack {
            BarcodeScannerView { isbn in
                isPresentingScanner = false
                Task { await viewModel.handleBarcodeScan(isbn: isbn) }
            } onError: { error in
                isPresentingScanner = false
                viewModel.errorMessage = error.localizedDescription
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { isPresentingScanner = false }
                }
            }
        }
    }
}

private struct SubjectShelfRow: View {
    let shelf: SubjectShelf
    let onRetry: () async -> Void

    @Environment(\.navigator) private var navigator

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(shelf.subject.displayName, systemImage: shelf.subject.systemImage)
                .font(.title3.bold())
                .padding(.horizontal)

            switch shelf.state {
            case .idle, .loading:
                ProgressView()
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            case .failed(let message):
                VStack(alignment: .leading, spacing: 8) {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Try again") { Task { await onRetry() } }
                        .font(.footnote)
                }
                .padding(.horizontal)
            case .loaded(let books) where books.isEmpty:
                Text("Nothing here right now.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            case .loaded(let books):
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(books) { book in
                            Button {
                                navigator.navigate(to: ExploreDestinations.bookDetail(book))
                            } label: {
                                BookCoverCell(
                                    title: book.title,
                                    author: book.author,
                                    coverURL: book.coverURL
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

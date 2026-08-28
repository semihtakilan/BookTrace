//
//  BooksTab.swift
//  Books
//
//  Created by Semih TAKILAN on 06.08.2026.
//

import SwiftUI
import NavigatorUI
import Models

struct BooksTab: View {
    private let viewModel: BooksViewModel

    init(viewModel: BooksViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ManagedNavigationStack {
            BooksContentView(viewModel: viewModel)
        }
    }
}

private struct BooksContentView: View {
    @Environment(AppRouteTypeManager.self) private var routeManager
    @Environment(LibraryChangeNotifier.self) private var libraryChangeNotifier
    @Bindable var viewModel: BooksViewModel
    @State private var isEditing = false

    var body: some View {
        Group {
            if viewModel.isEmpty {
                emptyState
            } else {
                libraryContent
            }
        }
        .navigationTitle("Library")
        .toolbar {
            if !viewModel.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        withAnimation { isEditing.toggle() }
                    }
                }
            }
        }
        .errorAlert($viewModel.error)
        .onAppear { viewModel.load() }
        // Explore'dan kitap eklendiğinde veya detayda bir şey değiştiğinde,
        // bu sekme hiç kaybolmamış olsa bile listeyi tazeler.
        .onChange(of: libraryChangeNotifier.revision) { _, _ in viewModel.load() }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Your library is empty", systemImage: "books.vertical")
        } description: {
            Text("Search, browse a shelf or scan a barcode in Explore to add your first book.")
        } actions: {
            Button("Go to Explore") {
                routeManager.selectedTab = .explore
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var libraryContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                if !viewModel.nowReading.isEmpty {
                    NowReadingSection(entries: viewModel.nowReading)
                }

                ForEach(viewModel.entriesByStatus, id: \.status) { group in
                    LibraryShelf(
                        title: Text(group.status.titleKey),
                        systemImage: group.status.systemImage,
                        entries: group.entries,
                        isEditing: isEditing,
                        onDelete: viewModel.delete
                    )
                }

                SectionHeader(title: "Ownership")

                ForEach(viewModel.entriesByOwnership, id: \.status) { group in
                    LibraryShelf(
                        title: Text(group.status.titleKey),
                        systemImage: group.status.systemImage,
                        entries: group.entries,
                        isEditing: isEditing,
                        onDelete: viewModel.delete
                    )
                }

                if !viewModel.entriesByCategory.isEmpty {
                    SectionHeader(title: "Categories")

                    ForEach(viewModel.entriesByCategory, id: \.category) { group in
                        LibraryShelf(
                            title: Text(group.category.name),
                            systemImage: "tag",
                            entries: group.entries,
                            isEditing: isEditing,
                            onDelete: viewModel.delete
                        )
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

private struct SectionHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.title2.bold())
            .padding(.horizontal)
            .padding(.top, 8)
    }
}

/// Ekranın en üstündeki "şu an okunan" bölümü — ilerleme çubuğu ve tahmini
/// kalan süre burada gösterilir.
private struct NowReadingSection: View {
    let entries: [LibraryEntry]
    @Environment(\.navigator) private var navigator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Now Reading")

            ForEach(entries) { entry in
                Button {
                    navigator.navigate(to: BooksDestinations.entryDetail(entry))
                } label: {
                    NowReadingCard(entry: entry)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
        }
    }
}

private struct NowReadingCard: View {
    let entry: LibraryEntry

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            RemoteBookCover(
                url: entry.book.coverURL,
                width: 84,
                height: 126,
                contentMode: .fill,
                fallbackTitle: entry.book.title,
                fallbackAuthor: entry.book.author
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(entry.book.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(entry.book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ReadingProgressView(entry: entry)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
    }
}

private struct LibraryShelf: View {
    /// Kategori rafları kullanıcı verisi taşıdığı için hazır `Text` alıyoruz;
    /// durum rafları çevrilebilir anahtardan geliyor.
    let title: Text
    let systemImage: String
    let entries: [LibraryEntry]
    let isEditing: Bool
    let onDelete: (LibraryEntry) -> Void

    @Environment(\.navigator) private var navigator

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                title + Text(" · \(entries.count)")
            } icon: {
                Image(systemName: systemImage)
            }
            .font(.headline)
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(entries) { entry in
                        Button {
                            navigator.navigate(to: BooksDestinations.entryDetail(entry))
                        } label: {
                            BookCoverCell(
                                title: entry.book.title,
                                author: entry.book.author,
                                coverURL: entry.book.coverURL
                            )
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .topTrailing) {
                            if isEditing {
                                Button(role: .destructive) {
                                    onDelete(entry)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title3)
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, .red)
                                }
                                .buttonStyle(.plain)
                                .offset(x: 8, y: -8)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, isEditing ? 8 : 0)
            }
        }
    }
}

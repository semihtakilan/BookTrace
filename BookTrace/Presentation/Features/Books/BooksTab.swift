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
                ToolbarItem(placement: .topBarTrailing) { sortMenu }
            }
        }
        .errorAlert($viewModel.error)
        .confirmationDialog(
            "Remove from library?",
            isPresented: isConfirmingDeletion,
            titleVisibility: .visible,
            presenting: viewModel.pendingDeletion
        ) { _ in
            Button("Remove", role: .destructive) { viewModel.confirmDeletion() }
            Button("Cancel", role: .cancel) { viewModel.cancelDeletion() }
        } message: { entry in
            Text("\(entry.book.title) and every reading session recorded for it will be deleted.")
        }
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

    // MARK: - Kütüphane

    private var libraryContent: some View {
        VStack(spacing: 0) {
            groupingPicker
            list
        }
        .searchable(text: $viewModel.searchText, prompt: "Title, author or tag")
    }

    private var groupingPicker: some View {
        Picker("Group by", selection: $viewModel.grouping) {
            Text("All").tag(LibraryGrouping.all)
            Text("Status").tag(LibraryGrouping.status)
            Text("Ownership").tag(LibraryGrouping.ownership)
            Text("Tags").tag(LibraryGrouping.category)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var list: some View {
        List {
            if viewModel.isShowingNowReading {
                Section {
                    ForEach(viewModel.nowReading) { entry in
                        NowReadingRow(entry: entry)
                    }
                } header: {
                    Text("Now Reading")
                }
            }

            ForEach(viewModel.sections) { section in
                Section {
                    ForEach(section.entries) { entry in
                        LibraryEntryRow(entry: entry)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.requestDeletion(of: entry)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    SectionHeader(kind: section.kind, count: section.entries.count)
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if viewModel.hasNoMatches {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $viewModel.sort) {
                Label("Recently added", systemImage: "clock").tag(LibrarySort.recentlyAdded)
                Label("Title", systemImage: "textformat").tag(LibrarySort.title)
                Label("Progress", systemImage: "chart.bar").tag(LibrarySort.progress)
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel("Sort books")
    }

    private var isConfirmingDeletion: Binding<Bool> {
        Binding(
            get: { viewModel.pendingDeletion != nil },
            set: { isPresented in if !isPresented { viewModel.cancelDeletion() } }
        )
    }
}

// MARK: - Bölüm başlığı

private struct SectionHeader: View {
    let kind: LibrarySectionKind
    let count: Int

    var body: some View {
        Label {
            title + Text(" · \(count)")
        } icon: {
            Image(systemName: systemImage)
        }
    }

    /// Etiket adları kullanıcı verisi olduğu için hazır `Text`; durum ve
    /// sahiplik başlıkları çevrilebilir anahtardan gelir.
    private var title: Text {
        switch kind {
        case .all:                  Text("All Books")
        case .status(let status):   Text(status.titleKey)
        case .ownership(let status): Text(status.titleKey)
        case .category(let category): Text(category.name)
        case .untagged:             Text("Untagged")
        }
    }

    private var systemImage: String {
        switch kind {
        case .all:                   "books.vertical"
        case .status(let status):    status.systemImage
        case .ownership(let status): status.systemImage
        case .category:              "tag"
        case .untagged:              "tag.slash"
        }
    }
}

// MARK: - Satırlar

/// Kütüphane listesinin standart satırı.
private struct LibraryEntryRow: View {
    let entry: LibraryEntry

    @Environment(\.navigator) private var navigator
    /// Sabit puntolar erişilebilirlik boyutlarında kesilmeye yol açıyordu;
    /// kapak da metinle birlikte büyüsün.
    @ScaledMetric(relativeTo: .subheadline) private var coverWidth: CGFloat = 44

    var body: some View {
        Button {
            navigator.navigate(to: BooksDestinations.entryDetail(entry))
        } label: {
            HStack(alignment: .top, spacing: 12) {
                RemoteBookCover(
                    url: entry.book.coverURL,
                    width: coverWidth,
                    height: coverWidth * 1.5,
                    contentMode: .fill,
                    fallbackTitle: entry.book.title,
                    fallbackAuthor: entry.book.author
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.book.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if !entry.book.author.isEmpty {
                        Text(entry.book.author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let percentage = entry.progressPercentage {
                        Text("\(percentage)% complete")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

/// "Şu an okunan" bölümündeki ilerleme çubuklu satır.
private struct NowReadingRow: View {
    let entry: LibraryEntry

    @Environment(\.navigator) private var navigator
    @ScaledMetric(relativeTo: .headline) private var coverWidth: CGFloat = 64

    var body: some View {
        Button {
            navigator.navigate(to: BooksDestinations.entryDetail(entry))
        } label: {
            HStack(alignment: .top, spacing: 14) {
                RemoteBookCover(
                    url: entry.book.coverURL,
                    width: coverWidth,
                    height: coverWidth * 1.5,
                    contentMode: .fill,
                    fallbackTitle: entry.book.title,
                    fallbackAuthor: entry.book.author
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.book.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(entry.book.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    ReadingProgressView(entry: entry)
                }

                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

import SwiftUI
import NavigatorUI
import Models

struct ExploreTab: View {
    let viewModel: ExploreViewModel

    var body: some View {
        ManagedNavigationStack { ExploreContentView(viewModel: viewModel) }
    }
}

private struct ExploreContentView: View {
    @Bindable var viewModel: ExploreViewModel
    @Environment(\.navigator) private var navigator
    @State private var isPresentingScanner = false
    @State private var pendingISBN: String?
    @State private var selectedSubject: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                ReadingPageHeader(eyebrow: "THE READING ROOM", title: "Find your next chapter.",
                                  subtitle: "Follow your curiosity. A story is waiting.")
                    .padding(.horizontal, 24)
                HStack(spacing: 10) {
                    ReadingSearchField(text: $viewModel.searchText, prompt: "Title, author or ISBN")
                    Button { isPresentingScanner = true } label: {
                        Image(systemName: "barcode.viewfinder").font(.title3)
                            .frame(width: 52, height: 52)
                            .background(ReadingStyle.sage, in: .rect(cornerRadius: 16))
                    }
                    .accessibilityLabel("Scan barcode")
                }
                .padding(.horizontal, 24)
                if viewModel.isShowingSearchResults {
                    searchResults.padding(.horizontal, 24)
                } else {
                    subjectFilters
                    if selectedSubject == nil, let book = featuredBook {
                        FeaturedBookCard(book: book)
                            .padding(.horizontal, 24)
                    }
                    ForEach(viewModel.shelves.filter { selectedSubject == nil || $0.id == selectedSubject }) { shelf in
                        SubjectShelfRow(shelf: shelf) { await viewModel.retry(shelf: shelf) }
                    }
                    Label("A world of books, a shelf of your own.", systemImage: "book.closed")
                        .font(.caption).foregroundStyle(ReadingStyle.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
            }
            .padding(.top, 18)
            .padding(.bottom, 32)
            .frame(maxWidth: 840)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .readingBackground()
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(verbatim: "BookTrace").font(.system(.headline, design: .serif))
            }
        }
        .task(id: viewModel.searchText) {
            guard viewModel.isShowingSearchResults else {
                viewModel.clearSearch()
                return
            }
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            await viewModel.performSearch()
        }
        .onAppear { viewModel.loadShelvesIfNeeded() }
        .sheet(isPresented: $isPresentingScanner, onDismiss: resolvePendingBarcode) {
            BarcodeScannerSheet { pendingISBN = $0 }
        }
        .onChange(of: viewModel.scannedBook) { _, book in
            guard let book else { return }
            viewModel.scannedBook = nil
            navigator.navigate(to: ExploreDestinations.bookDetail(book))
        }
        .overlay {
            if viewModel.isResolvingBarcode {
                ZStack {
                    ReadingStyle.background.opacity(0.85).ignoresSafeArea()
                    ProgressView("Looking up that barcode…")
                        .padding(32).background(ReadingStyle.surface, in: .rect(cornerRadius: 22))
                }
            }
        }
        .errorAlert($viewModel.error)
    }

    private func resolvePendingBarcode() {
        guard let isbn = pendingISBN else { return }
        pendingISBN = nil
        Task { await viewModel.handleBarcodeScan(isbn: isbn) }
    }

    private var featuredBook: BookReference? {
        guard let shelf = viewModel.shelves.first, case .loaded(let books) = shelf.state else { return nil }
        return books.dropFirst().first ?? books.first
    }

    private var subjectFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ReadingFilterChip(title: "Discover", isSelected: selectedSubject == nil) { selectedSubject = nil }
                ForEach(viewModel.shelves) { shelf in
                    ReadingFilterChip(title: LocalizedStringKey(shelf.subject.displayName), isSelected: selectedSubject == shelf.id) {
                        selectedSubject = shelf.id
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        switch viewModel.searchState {
        case .idle, .loading:
            ProgressView("Searching…")
                .frame(maxWidth: .infinity, minHeight: 220)
        case .failed(let error):
            VStack(spacing: 16) {
                Image(systemName: "wifi.exclamationmark").font(.largeTitle).foregroundStyle(ReadingStyle.secondary)
                Text("Search failed").font(ReadingStyle.title(.title2))
                Text(error.message).font(.subheadline).foregroundStyle(ReadingStyle.secondary)
                if error.isRetryable {
                    Button("Try again") { Task { await viewModel.performSearch() } }
                        .buttonStyle(ReadingButtonStyle())
                }
            }
            .multilineTextAlignment(.center).readingCard()
        case .loaded(let books) where books.isEmpty:
            ReadingEmptyState(symbol: "magnifyingglass", title: "A different way to find it",
                              message: "No books matched. Try the author’s name, a shorter title, or an ISBN.",
                              actionTitle: "Browse the shelves") { viewModel.clearSearch() }
        case .loaded(let books):
            LazyVStack(alignment: .leading, spacing: 12) {
                ReadingSectionHeading(title: "Search results", detail: String(books.count)).padding(.bottom, 6)
                ForEach(books) { book in
                    Button { navigator.navigate(to: ExploreDestinations.bookDetail(book)) } label: {
                        HStack(spacing: 12) {
                            BookRowView(title: book.title, author: book.author, coverURL: book.coverURL,
                                        subtitle: book.publicationYear)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(ReadingStyle.secondary)
                                .accessibilityHidden(true)
                        }
                        .readingCard(padding: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct FeaturedBookCard: View {
    let book: BookReference
    @Environment(\.navigator) private var navigator
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button { navigator.navigate(to: ExploreDestinations.bookDetail(book)) } label: {
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 20)) : AnyLayout(HStackLayout(alignment: .center, spacing: 20))
            layout {
                VStack(alignment: .leading, spacing: 12) {
                    ReadingEyebrow(title: "FROM THE SHELVES")
                    Text(book.title).font(ReadingStyle.title(.title2)).lineLimit(4)
                    Text(book.author).font(.caption).foregroundStyle(ReadingStyle.secondary).lineLimit(2)
                    Label("Take a closer look", systemImage: "arrow.up.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(ReadingStyle.accent)
                        .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                RemoteBookCover(url: book.coverURL, width: 100, height: 150, contentMode: .fit,
                                fallbackTitle: book.title, fallbackAuthor: book.author)
                    .rotationEffect(.degrees(5))
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 3, y: 8)
                    .padding(4)
            }
            .padding(24)
            .background(ReadingStyle.sage, in: .rect(cornerRadius: 24))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

private struct SubjectShelfRow: View {
    let shelf: SubjectShelf
    let onRetry: () async -> Void
    @Environment(\.navigator) private var navigator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ReadingSectionHeading(title: LocalizedStringKey(shelf.subject.displayName))
                .padding(.horizontal, 24)
            switch shelf.state {
            case .idle, .loading:
                ProgressView().frame(maxWidth: .infinity, minHeight: 180)
            case .failed(let error):
                VStack(alignment: .leading, spacing: 12) {
                    Text(error.message).font(.footnote).foregroundStyle(ReadingStyle.secondary)
                    if error.isRetryable {
                        Button("Try again") { Task { await onRetry() } }.font(.subheadline.weight(.medium))
                    }
                }
                .readingCard().padding(.horizontal, 24)
            case .loaded(let books) where books.isEmpty:
                Text("Nothing here right now.").font(.footnote).foregroundStyle(ReadingStyle.secondary)
                    .padding(.horizontal, 24)
            case .loaded(let books):
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 20) {
                        ForEach(books) { book in
                            Button { navigator.navigate(to: ExploreDestinations.bookDetail(book)) } label: {
                                BookCoverCell(title: book.title, author: book.author, coverURL: book.coverURL)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)
                }
            }
        }
    }
}

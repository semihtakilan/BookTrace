import SwiftUI
import NavigatorUI
import Models

struct ExploreTab: View {
    let viewModel: ExploreViewModel

    var body: some View {
        ManagedNavigationStack { ExploreContentView(viewModel: viewModel) }
            .environment(viewModel)
    }
}

private struct ExploreContentView: View {
    @Bindable var viewModel: ExploreViewModel
    @Environment(\.navigator) private var navigator
    @State private var isPresentingScanner = false
    @State private var pendingISBN: String?

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 10) {
                        ReadingSearchField(text: $viewModel.searchText, prompt: "Title, author or ISBN")
                        Button { isPresentingScanner = true } label: {
                            Image(systemName: "barcode.viewfinder").font(.title3)
                                .frame(width: 52, height: 52)
                                .background(ReadingStyle.sage, in: .rect(cornerRadius: 16))
                        }
                        .accessibilityLabel("Scan barcode")
                    }
                    .padding(.horizontal, 20)
                    if viewModel.isShowingSearchResults {
                        searchResults.padding(.horizontal, 20)
                    } else {
                        discoveryContent(width: min(geometry.size.width, 840))
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 36)
                .frame(maxWidth: 840)
                .frame(maxWidth: .infinity)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .readingBackground()
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.large)
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

    private func discoveryContent(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 30) {
            if !viewModel.spotlights.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        ReadingSectionHeading(title: "Open something new")
                        Button {
                            guard let book = viewModel.discoverableBooks.randomElement() else { return }
                            navigator.navigate(to: ExploreDestinations.bookDetail(book))
                        } label: {
                            Image(systemName: "shuffle").frame(width: 44, height: 44)
                                .background(ReadingStyle.surface, in: .circle)
                        }
                        .accessibilityLabel("Surprise me")
                    }
                    .padding(.horizontal, 20)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(viewModel.spotlights) { spotlight in
                                DiscoverSpotlightCard(spotlight: spotlight, width: min(width - 56, 380))
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .contentMargins(.horizontal, 20, for: .scrollContent)
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                ReadingSectionHeading(title: "Follow your curiosity")
                LazyVGrid(columns: topicColumns, spacing: 12) {
                    ForEach(viewModel.shelves) { shelf in
                        DiscoverSubjectTile(subject: shelf.subject) {
                            navigator.navigate(to: ExploreDestinations.collection(.subject(shelf.subject)))
                        }
                    }
                }
            }
            .padding(.horizontal, 20)

            if !viewModel.shortReads.isEmpty {
                DiscoverBookShelf(title: "Small books, big worlds", subtitle: "250 pages or fewer",
                                  books: Array(viewModel.shortReads.prefix(8)), width: width,
                                  onSeeAll: { navigator.navigate(to: ExploreDestinations.collection(.shortReads)) })
            }

            ForEach(viewModel.shelves.prefix(2)) { shelf in
                DiscoverSubjectShelf(shelf: shelf, width: width,
                                     onSeeAll: { navigator.navigate(to: ExploreDestinations.collection(.subject(shelf.subject))) },
                                     onRetry: { await viewModel.retry(shelf: shelf) })
            }
        }
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var topicColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), alignment: .top), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
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

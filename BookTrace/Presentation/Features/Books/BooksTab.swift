import SwiftUI
import NavigatorUI
import Models

struct BooksTab: View {
    let viewModel: BooksViewModel

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
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ReadingPageHeader(eyebrow: "A SPACE FOR YOUR STORIES", title: "Your library", subtitle: "A little reading, every day.")
                if viewModel.isEmpty {
                    emptyState
                } else {
                    libraryContent
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 32)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .readingBackground()
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(verbatim: "BookTrace").font(.system(.headline, design: .serif))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { routeManager.selectedTab = .explore } label: {
                    Image(systemName: "plus").frame(width: 32, height: 32)
                }
                .accessibilityLabel("Find a book")
            }
        }
        .errorAlert($viewModel.error)
        .confirmationDialog("Remove from library?", isPresented: isConfirmingDeletion,
                            titleVisibility: .visible, presenting: viewModel.pendingDeletion) { _ in
            Button("Remove", role: .destructive) { viewModel.confirmDeletion() }
            Button("Cancel", role: .cancel) { viewModel.cancelDeletion() }
        } message: { entry in
            Text("\(entry.book.title) and every reading session recorded for it will be deleted.")
        }
        .onAppear { viewModel.load() }
        .onChange(of: libraryChangeNotifier.revision) { _, _ in viewModel.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            ReadingEmptyState(symbol: "books.vertical", title: "Every reader starts\nwith one book.",
                              message: "Collect the books you love. Make time for their stories. Keep a trace of every page.",
                              actionTitle: "Find your first book") { routeManager.selectedTab = .explore }
            Label("Your books and reading sessions stay on this device.", systemImage: "lock")
                .font(.caption)
                .foregroundStyle(ReadingStyle.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }

    private var libraryContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            if viewModel.isShowingNowReading {
                VStack(alignment: .leading, spacing: 14) {
                    ReadingSectionHeading(title: "Now Reading", detail: String(viewModel.nowReading.count))
                    ForEach(viewModel.nowReading) { entry in
                        NowReadingCard(entry: entry)
                    }
                }
            }

            if viewModel.shelfCount > 0 {
                VStack(spacing: 14) {
                    HStack {
                        ReadingSectionHeading(title: "On your shelf", detail: String(viewModel.shelfCount))
                        organizationMenu
                    }
                    ReadingSearchField(text: $viewModel.searchText, prompt: "Title, author or tag")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ReadingFilterChip(title: "All", isSelected: viewModel.statusFilter == nil,
                                              count: viewModel.shelfCount) { viewModel.statusFilter = nil }
                            ForEach(BooksViewModel.shelfStatuses, id: \.self) { status in
                                ReadingFilterChip(title: status.titleKey, isSelected: viewModel.statusFilter == status,
                                                  count: viewModel.entries.filter { $0.readingStatus == status }.count) {
                                    viewModel.statusFilter = status
                                }
                            }
                        }
                    }
                    .contentMargins(.trailing, 1)
                }
            }

            if viewModel.hasNoMatches {
                VStack(spacing: 12) {
                    Text("No books here yet").font(ReadingStyle.title(.title3))
                    Text("Try a different search or choose another shelf.")
                        .font(.subheadline).foregroundStyle(ReadingStyle.secondary)
                    Button("Show all books") {
                        viewModel.searchText = ""
                        viewModel.statusFilter = nil
                    }
                    .buttonStyle(ReadingButtonStyle(prominent: false))
                }
                .multilineTextAlignment(.center)
                .readingCard()
            } else {
                ForEach(viewModel.sections) { section in
                    let entries = section.entries
                    if !entries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            if viewModel.grouping != .all {
                                sectionTitle(section.kind)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(ReadingStyle.secondary)
                            }
                            ForEach(entries) { entry in
                                LibraryEntryRow(entry: entry) { viewModel.requestDeletion(of: entry) }
                            }
                        }
                    }
                }
                if viewModel.isShowingNowReading {
                    discoverCard
                }
            }
        }
    }

    private var discoverCard: some View {
        Button { routeManager.selectedTab = .explore } label: {
            HStack(spacing: 16) {
                Image(systemName: "sparkle").font(.title2).foregroundStyle(ReadingStyle.gold)
                VStack(alignment: .leading, spacing: 5) {
                    Text("There’s always another story.").font(ReadingStyle.title(.title3))
                    Text("Find your next read").font(.subheadline).foregroundStyle(ReadingStyle.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right").accessibilityHidden(true)
            }
            .readingCard()
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var organizationMenu: some View {
        Menu {
            Picker("Sort by", selection: $viewModel.sort) {
                Label("Recently added", systemImage: "clock").tag(LibrarySort.recentlyAdded)
                Label("Title", systemImage: "textformat").tag(LibrarySort.title)
                Label("Progress", systemImage: "chart.bar").tag(LibrarySort.progress)
            }
            Picker("Group by", selection: $viewModel.grouping) {
                Text("All").tag(LibraryGrouping.all)
                Text("Status").tag(LibraryGrouping.status)
                Text("Ownership").tag(LibraryGrouping.ownership)
                Text("Tags").tag(LibraryGrouping.category)
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .frame(width: 44, height: 44)
                .background(ReadingStyle.surface, in: .circle)
        }
        .accessibilityLabel("Sort and group books")
    }

    private func sectionTitle(_ kind: LibrarySectionKind) -> Text {
        switch kind {
        case .all: Text("All Books")
        case .status(let status): Text(status.titleKey)
        case .ownership(let status): Text(status.titleKey)
        case .category(let category): Text(category.name)
        case .untagged: Text("Untagged")
        }
    }

    private var isConfirmingDeletion: Binding<Bool> {
        Binding(get: { viewModel.pendingDeletion != nil },
                set: { if !$0 { viewModel.cancelDeletion() } })
    }
}

private struct LibraryEntryRow: View {
    let entry: LibraryEntry
    let onRemove: () -> Void
    @Environment(\.navigator) private var navigator
    private let coverWidth: CGFloat = 56

    var body: some View {
        Button { navigator.navigate(to: BooksDestinations.entryDetail(entry)) } label: {
            HStack(spacing: 16) {
                RemoteBookCover(url: entry.book.coverURL, width: coverWidth, height: coverWidth * 1.5,
                                contentMode: .fit, fallbackTitle: entry.book.title, fallbackAuthor: entry.book.author)
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.book.title).font(.system(.headline, design: .serif)).lineLimit(3)
                    Text(entry.book.author).font(.caption).foregroundStyle(ReadingStyle.secondary).lineLimit(2)
                    Label(entry.readingStatus.titleKey, systemImage: entry.readingStatus.systemImage)
                        .font(.caption2.weight(.medium)).foregroundStyle(ReadingStyle.accent)
                    if entry.readingStatus == .finished, let total = entry.effectivePageCount {
                        Text("\(total) of \(total) pages")
                            .font(.caption).foregroundStyle(ReadingStyle.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(ReadingStyle.secondary)
                    .accessibilityHidden(true)
            }
            .readingCard(padding: 16)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .contextMenu { Button("Remove from Library", role: .destructive, action: onRemove) }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Remove from Library", onRemove)
    }
}

private struct NowReadingCard: View {
    let entry: LibraryEntry
    @Environment(\.navigator) private var navigator
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button { navigator.navigate(to: BooksDestinations.entryDetail(entry)) } label: {
                let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 20)) : AnyLayout(HStackLayout(alignment: .center, spacing: 22))
                layout {
                    RemoteBookCover(url: entry.book.coverURL, width: 80, height: 120, contentMode: .fit,
                                    fallbackTitle: entry.book.title, fallbackAuthor: entry.book.author)
                        .shadow(color: .black.opacity(0.15), radius: 9, x: 0, y: 6)
                    VStack(alignment: .leading, spacing: 10) {
                        ReadingEyebrow(title: "NOW READING")
                        Text(entry.book.title).font(ReadingStyle.title(.title2)).lineLimit(3)
                        Text(entry.book.author).font(.subheadline).foregroundStyle(ReadingStyle.secondary).lineLimit(2)
                        HStack(spacing: 4) {
                            Text("Book details")
                            Image(systemName: "arrow.up.right").accessibilityHidden(true)
                        }
                        .font(.caption.weight(.medium)).foregroundStyle(ReadingStyle.accent)
                        .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            ReadingProgressView(entry: entry)
            Button { navigator.navigate(to: BooksDestinations.readingSession(entry)) } label: {
                Label("Continue reading", systemImage: "play.fill")
            }
            .buttonStyle(ReadingButtonStyle())
        }
        .padding(20)
        .background(ReadingStyle.sage, in: .rect(cornerRadius: 26))
    }
}

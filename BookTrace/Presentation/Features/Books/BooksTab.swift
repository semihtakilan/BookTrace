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

/// Kütüphane: önce okunan kitap, sonra raf.
///
/// Eski düzende ekranın ilk üçte biri başlık bloğuydu ve kitaplar tam genişlikte
/// satırlar hâlinde dizildiği için bir ekranda ancak üç kitap görünüyordu.
/// Şimdi başlık gezinme çubuğunda, kitaplar ise kapaklarıyla ızgarada.
private struct BooksContentView: View {
    @Environment(AppRouteTypeManager.self) private var routeManager
    @Environment(LibraryChangeNotifier.self) private var libraryChangeNotifier
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable var viewModel: BooksViewModel

    @State private var visibleReadingID: String?

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    if viewModel.isEmpty {
                        emptyState.padding(.horizontal, 20)
                    } else {
                        ReadingStreakStrip(days: viewModel.streakDays, activity: viewModel.weekActivity)
                            .padding(.horizontal, 20)
                        nowReading(width: min(geometry.size.width, 760))
                        shelf(width: min(geometry.size.width, 760))
                        // Raf boşken de görünür: iki kitap okuyan ama rafı boş
                        // olan kullanıcı için ekranın altı tamamen boş kalıyordu.
                        discoverCard.padding(.horizontal, 20)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 36)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .readingBackground()
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
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

    // MARK: - Boş kütüphane

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

    // MARK: - Okunanlar

    @ViewBuilder
    private func nowReading(width: CGFloat) -> some View {
        if viewModel.nowReading.count == 1, let entry = viewModel.nowReading.first {
            NowReadingCard(entry: entry)
                .padding(.horizontal, 20)
        } else if viewModel.nowReading.count > 1 {
            VStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(viewModel.nowReading) { entry in
                            NowReadingCard(entry: entry)
                                .frame(width: min(width - 56, 420))
                                .id(entry.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $visibleReadingID)
                .contentMargins(.horizontal, 20, for: .scrollContent)

                // Kaç kitap okunduğunu ve hangisine bakıldığını gösteren noktalar.
                HStack(spacing: 7) {
                    ForEach(viewModel.nowReading) { entry in
                        Circle()
                            .fill(entry.id == currentReadingID ? ReadingStyle.accent : ReadingStyle.line)
                            .frame(width: 6, height: 6)
                    }
                }
                .accessibilityHidden(true)
            }
        }
    }

    /// Kaydırma konumu henüz oturmadıysa ilk kitap seçili sayılır.
    private var currentReadingID: String? {
        visibleReadingID ?? viewModel.nowReading.first?.id
    }

    // MARK: - Raf

    @ViewBuilder
    private func shelf(width: CGFloat) -> some View {
        if viewModel.shelfCount > 0 || viewModel.hasNoMatches {
            VStack(alignment: .leading, spacing: 16) {
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

                if viewModel.hasNoMatches {
                    noMatches
                } else {
                    shelfSections(width: width)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func shelfSections(width: CGFloat) -> some View {
        let columns = dynamicTypeSize.isAccessibilitySize ? 2 : 3
        let spacing: CGFloat = 16
        let tileWidth = (width - 40 - spacing * CGFloat(columns - 1)) / CGFloat(columns)

        return VStack(alignment: .leading, spacing: 26) {
            ForEach(viewModel.sections) { section in
                if !section.entries.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        if viewModel.grouping != .all {
                            sectionTitle(section.kind)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(ReadingStyle.secondary)
                        }
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .top),
                                           count: columns),
                            alignment: .leading, spacing: 22
                        ) {
                            ForEach(section.entries) { entry in
                                shelfTile(entry: entry, width: tileWidth)
                            }
                        }
                    }
                }
            }
        }
    }

    private func shelfTile(entry: LibraryEntry, width: CGFloat) -> some View {
        NavigationLinkButton(entry: entry, width: width)
            .contextMenu {
                Button("Remove from Library", role: .destructive) { viewModel.requestDeletion(of: entry) }
            }
            .accessibilityAction(named: "Remove from Library") { viewModel.requestDeletion(of: entry) }
    }

    private var noMatches: some View {
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

/// Raf karesini gezinmeye bağlayan sarmalayıcı.
///
/// `Navigator` ortamı `contextMenu` içinden de okunabilsin diye ayrı bir
/// görünüm: menü, kendisini taşıyan görünümün ortamını devralıyor.
private struct NavigationLinkButton: View {
    let entry: LibraryEntry
    let width: CGFloat
    @Environment(\.navigator) private var navigator

    var body: some View {
        Button {
            navigator.navigate(to: BooksDestinations.entryDetail(entry))
        } label: {
            ShelfBookTile(entry: entry, width: width)
        }
        .buttonStyle(.plain)
    }
}

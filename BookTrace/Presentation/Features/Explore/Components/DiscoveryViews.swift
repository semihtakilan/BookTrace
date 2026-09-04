import SwiftUI
import NavigatorUI
import Models

/// Collections reuse the loaded shelves, keeping navigation instant and offline-capable.
enum DiscoverCollection: Hashable {
    case subject(BookSubject)
    case shortReads

    var title: LocalizedStringKey {
        switch self {
        case .subject(let subject): LocalizedStringKey(subject.displayName)
        case .shortReads: "Small books, big worlds"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .subject(let subject): subject.discoverySubtitle
        case .shortReads: "250 pages or fewer"
        }
    }
}

extension BookSubject {
    var discoverySubtitle: LocalizedStringKey {
        switch query {
        case "fiction": "Stories to disappear into."
        case "science fiction": "Imagine another world."
        case "history": "The past, brought closer."
        case "philosophy": "Make room for a new idea."
        case "computers": "Understand what comes next."
        case "biography": "Extraordinary ordinary lives."
        default: "Follow your curiosity. A story is waiting."
        }
    }

    /// Konunun havası — kartların rengi ve dokusu buradan geliyor.
    var ambience: BookAmbience {
        BookAmbience.resolve(subjects: [query], title: displayName)
    }
}

// MARK: - Kitap karesi

/// Keşif raflarındaki tek kitap.
///
/// Eskiden kapak, açık yeşil bir kutunun içinde duruyordu; altı rafta yan yana
/// duran kutular kapakların kendisinden daha görünürdü. Artık kutu yok, kitap
/// var.
struct DiscoverBookCell: View {
    let book: BookReference
    let width: CGFloat

    var body: some View {
        DiscoverBookCellBody(book: book, width: width)
            .bookAtmosphere(book)
    }
}

private struct DiscoverBookCellBody: View {
    let book: BookReference
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BookVolumeView(book: book, height: BookVolumeView.height(fittingWidth: width), progress: nil)

            Text(book.title)
                .font(.system(.subheadline, design: .serif, weight: .medium))
                .foregroundStyle(ReadingStyle.ink)
                .modifier(BookTextLines(count: 3))

            if !book.author.isEmpty {
                Text(book.author)
                    .font(.caption2)
                    .foregroundStyle(ReadingStyle.secondary)
                    .modifier(BookTextLines(count: 2))
            }
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Öne çıkan kitap

struct DiscoverSpotlightCard: View {
    let spotlight: DiscoverSpotlight
    let width: CGFloat

    var body: some View {
        DiscoverSpotlightCardBody(spotlight: spotlight, width: width)
            .bookAtmosphere(spotlight.book)
    }
}

private struct DiscoverSpotlightCardBody: View {
    let spotlight: DiscoverSpotlight
    let width: CGFloat

    @Environment(\.navigator) private var navigator
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.bookPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    private var book: BookReference { spotlight.book }
    private var ambience: BookAmbience { spotlight.subject.ambience }

    var body: some View {
        Button { navigator.navigate(to: ExploreDestinations.bookDetail(book)) } label: {
            VStack(alignment: .leading, spacing: 16) {
                Label(LocalizedStringKey(spotlight.subject.displayName), systemImage: ambience.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.accent(colorScheme))

                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: 18))
                layout {
                    BookVolumeView(book: book, height: 140, progress: nil)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(book.title)
                            .font(.system(.title3, design: .serif, weight: .medium))
                            .foregroundStyle(ReadingStyle.ink)
                            .modifier(BookTextLines(count: 3))
                        Text(book.author)
                            .font(.caption)
                            .foregroundStyle(ReadingStyle.secondary)
                            .lineLimit(2, reservesSpace: true)
                        if let count = book.pageCount, count > 0 {
                            Text("\(count) pages")
                                .font(.caption2)
                                .foregroundStyle(ReadingStyle.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    Text("Take a closer look").font(.caption.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption.weight(.semibold))
                }
                .foregroundStyle(palette.accent(colorScheme))
            }
            .padding(20)
            .frame(width: width, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 26)
                    .fill(LinearGradient(colors: [palette.wash(colorScheme), palette.washEdge(colorScheme)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 26)
                    .strokeBorder(palette.accent(colorScheme).opacity(0.16), lineWidth: 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Konu karesi

/// Altı konu kartı. Her biri kendi rengiyle çizilir; eskiden altısı da aynı
/// beyaz kutuydu ve göz aralarında bir fark bulamıyordu.
struct DiscoverSubjectTile: View {
    let subject: BookSubject
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var palette: BookPalette { subject.ambience.signaturePalette }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: subject.ambience.systemImage)
                    .font(.title3)
                    .foregroundStyle(palette.accent(colorScheme))
                    .accessibilityHidden(true)

                Text(LocalizedStringKey(subject.displayName))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ReadingStyle.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [palette.wash(colorScheme), palette.washEdge(colorScheme)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(palette.accent(colorScheme).opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Raflar

struct DiscoverBookShelf: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let books: [BookReference]
    let width: CGFloat
    let onSeeAll: () -> Void

    @Environment(\.navigator) private var navigator
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
            layout {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(ReadingStyle.title(.title2)).accessibilityAddTraits(.isHeader)
                    Text(subtitle).font(.caption).foregroundStyle(ReadingStyle.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button("See all", action: onSeeAll)
                    .font(.caption.weight(.semibold)).frame(minHeight: 44)
                    .accessibilityLabel(Text("See all") + Text(verbatim: " ") + Text(title))
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 18) {
                    ForEach(books) { book in
                        Button { navigator.navigate(to: ExploreDestinations.bookDetail(book)) } label: {
                            DiscoverBookCell(book: book,
                                             width: dynamicTypeSize.isAccessibilitySize ? 190 : min(132, (width - 56) / 2.6))
                        }
                        .buttonStyle(.plain)
                        // Kenara yaklaşan kitaplar hafifçe küçülür; rafın
                        // devam ettiği kaydırmadan önce de anlaşılıyor.
                        .scrollTransition(reduceMotion ? .identity : .interactive) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.93)
                                .opacity(phase.isIdentity ? 1 : 0.7)
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
    }
}

struct DiscoverSubjectShelf: View {
    let shelf: SubjectShelf
    let width: CGFloat
    let onSeeAll: () -> Void
    let onRetry: () async -> Void

    var body: some View {
        switch shelf.state {
        case .loaded(let books) where !books.isEmpty:
            DiscoverBookShelf(title: LocalizedStringKey(shelf.subject.displayName),
                              subtitle: shelf.subject.discoverySubtitle,
                              books: Array(books.prefix(8)), width: width, onSeeAll: onSeeAll)
        default:
            VStack(alignment: .leading, spacing: 16) {
                ReadingSectionHeading(title: LocalizedStringKey(shelf.subject.displayName))
                DiscoverShelfState(state: shelf.state, onRetry: onRetry)
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Koleksiyon ekranı

struct DiscoverCollectionScreen: View {
    let collection: DiscoverCollection
    @Environment(ExploreViewModel.self) private var viewModel

    var body: some View {
        DiscoverCollectionView(collection: collection, viewModel: viewModel)
    }
}

private struct DiscoverCollectionView: View {
    let collection: DiscoverCollection
    @Bindable var viewModel: ExploreViewModel
    @Environment(\.navigator) private var navigator
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var shelf: SubjectShelf? {
        guard case .subject(let subject) = collection else { return nil }
        return viewModel.shelves.first { $0.id == subject.id }
    }

    private var books: [BookReference] {
        if let shelf, case .loaded(let books) = shelf.state { return books }
        if collection == .shortReads { return viewModel.shortReads }
        return []
    }

    var body: some View {
        GeometryReader { geometry in
            let columns = dynamicTypeSize.isAccessibilitySize ? 2 : (geometry.size.width > 650 ? 4 : 3)
            let spacing: CGFloat = 16
            let tileWidth = (min(geometry.size.width, 840) - 40 - CGFloat(columns - 1) * spacing) / CGFloat(columns)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(collection.subtitle).font(.subheadline).foregroundStyle(ReadingStyle.secondary)
                        if !books.isEmpty {
                            Text("\(books.count) books").font(.caption.monospacedDigit()).foregroundStyle(ReadingStyle.secondary)
                        }
                    }
                    if !books.isEmpty {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .top),
                                                 count: columns),
                                  alignment: .leading, spacing: 26) {
                            ForEach(books) { book in
                                Button { navigator.navigate(to: ExploreDestinations.bookDetail(book)) } label: {
                                    DiscoverBookCell(book: book, width: tileWidth)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else if let shelf {
                        DiscoverShelfState(state: shelf.state) { await viewModel.retry(shelf: shelf) }
                    } else {
                        Text("Nothing here right now.").foregroundStyle(ReadingStyle.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: 840).frame(maxWidth: .infinity)
            }
        }
        .readingBackground()
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .tabBar)
    }
}

private struct DiscoverShelfState: View {
    let state: ViewState<[BookReference]>
    let onRetry: () async -> Void

    var body: some View {
        switch state {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity, minHeight: 160)
        case .failed(let error):
            VStack(alignment: .leading, spacing: 12) {
                Text(error.message).font(.subheadline).foregroundStyle(ReadingStyle.secondary)
                if error.isRetryable {
                    Button("Try again") { Task { await onRetry() } }
                        .buttonStyle(ReadingButtonStyle(prominent: false))
                }
            }
            .readingCard()
        case .loaded:
            Text("Nothing here right now.").font(.subheadline).foregroundStyle(ReadingStyle.secondary)
        }
    }
}

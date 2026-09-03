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

    var discoveryTint: Color {
        switch query {
        case "fiction", "biography": ReadingStyle.gold
        default: ReadingStyle.accent
        }
    }
}

struct DiscoverSpotlightCard: View {
    let spotlight: DiscoverSpotlight
    let width: CGFloat
    @Environment(\.navigator) private var navigator
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var book: BookReference { spotlight.book }

    var body: some View {
        Button { navigator.navigate(to: ExploreDestinations.bookDetail(book)) } label: {
            VStack(alignment: .leading, spacing: 18) {
                Label(LocalizedStringKey(spotlight.subject.displayName), systemImage: spotlight.subject.systemImage)
                    .font(.caption.weight(.semibold)).foregroundStyle(ReadingStyle.accent)
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: 18))
                layout {
                    RemoteBookCover(url: book.coverURL, width: 88, height: 132, contentMode: .fit,
                                    fallbackTitle: book.title, fallbackAuthor: book.author)
                        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 6)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(book.title).font(ReadingStyle.title(.title3))
                            .modifier(BookTextLines(count: 3))
                        Text(book.author).font(.caption).foregroundStyle(ReadingStyle.secondary)
                            .lineLimit(2, reservesSpace: true)
                        if let count = book.pageCount, count > 0 {
                            Text("\(count) pages").font(.caption2).foregroundStyle(ReadingStyle.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Text("Take a closer look").font(.caption.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption.weight(.semibold))
                }
                .foregroundStyle(ReadingStyle.accent)
                .padding(.top, 4)
            }
            .padding(20)
            .frame(width: width, alignment: .leading)
            .background(ReadingStyle.sage, in: .rect(cornerRadius: 24))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "bookmark.fill").font(.title2)
                    .foregroundStyle(spotlight.subject.discoveryTint.opacity(0.35))
                    .padding(.trailing, 20).accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

struct DiscoverSubjectTile: View {
    let subject: BookSubject
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: subject.systemImage).font(.title3)
                        .foregroundStyle(subject.discoveryTint)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.caption)
                        .foregroundStyle(ReadingStyle.secondary)
                }
                .accessibilityHidden(true)
                Text(LocalizedStringKey(subject.displayName))
                    .font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .padding(16)
            .background(ReadingStyle.surface, in: .rect(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(ReadingStyle.line, lineWidth: 0.7) }
        }
        .buttonStyle(.plain)
    }
}

struct DiscoverBookShelf: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let books: [BookReference]
    let width: CGFloat
    let onSeeAll: () -> Void
    @Environment(\.navigator) private var navigator
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                    .accessibilityLabel(Text("See all") + Text(" ") + Text(title))
            }
            .padding(.horizontal, 24)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(books) { book in
                        Button { navigator.navigate(to: ExploreDestinations.bookDetail(book)) } label: {
                            BookCoverCell(title: book.title, author: book.author, coverURL: book.coverURL,
                                          width: dynamicTypeSize.isAccessibilitySize ? 200 : min(148, (width - 64) / 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
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
            .padding(.horizontal, 24)
        }
    }
}

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
            let columns = dynamicTypeSize.isAccessibilitySize ? 1 : (geometry.size.width > 650 ? 3 : 2)
            let tileWidth = (min(geometry.size.width, 840) - 48 - CGFloat(columns - 1) * 20) / CGFloat(columns)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(collection.title).font(ReadingStyle.title(.largeTitle)).accessibilityAddTraits(.isHeader)
                        Text(collection.subtitle).font(.subheadline).foregroundStyle(ReadingStyle.secondary)
                        if !books.isEmpty {
                            Text("\(books.count) books").font(.caption.monospacedDigit()).foregroundStyle(ReadingStyle.secondary)
                        }
                    }
                    if !books.isEmpty {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .top), count: columns),
                                  alignment: .leading, spacing: 28) {
                            ForEach(books) { book in
                                Button { navigator.navigate(to: ExploreDestinations.bookDetail(book)) } label: {
                                    BookCoverCell(title: book.title, author: book.author, coverURL: book.coverURL, width: tileWidth)
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
                .padding(24)
                .frame(maxWidth: 840).frame(maxWidth: .infinity)
            }
        }
        .readingBackground()
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.inline)
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

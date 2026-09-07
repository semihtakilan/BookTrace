//
//  YearReviewView.swift
//  Release
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Models
import SwiftUI

struct YearReviewView: View {
    @Environment(ReadingWorkspace.self) private var workspace
    @Environment(EntitlementStore.self) private var entitlementStore
    @Environment(BookPaletteStore.self) private var palettes
    @Environment(\.locale) private var locale
    @State private var showsPaywall = false
    @State private var sharedCard: ReviewShareImage?
    @State private var shareError = false

    private var palette: BookPalette {
        workspace.yearInReview.bookOfYear.map { palettes.palette(for: $0) }
            ?? workspace.yearInReview.fastestBook.map { palettes.palette(for: $0) }
            ?? .neutral
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ReadingYearSelector()
                Text("A year between the pages").font(ReadingStyle.title(.title))
                Text("Keep a little reminder of the stories and reading moments that made your year.")
                    .font(.subheadline).foregroundStyle(ReadingStyle.secondary)
                ReviewArtwork(kind: .summary, summary: workspace.yearInReview, palette: palette, locale: locale)
                    .frame(maxWidth: .infinity)
                Button { prepareImage(.summary, highResolution: false) } label: {
                    Label("Share your reading year", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(ReadingButtonStyle())
                if entitlementStore.isPro {
                    Button { prepareImage(.summary, highResolution: true) } label: {
                        Label("High-resolution summary", systemImage: "sparkles")
                    }
                    .buttonStyle(ReadingButtonStyle(prominent: false))
                    ReadingSectionHeading(title: "More of your reading story")
                    ForEach(ReviewCardKind.allCases.filter { $0 != .summary }) { kind in
                        VStack(spacing: 14) {
                            ReviewArtwork(kind: kind, summary: workspace.yearInReview, palette: palette, locale: locale)
                            Button { prepareImage(kind, highResolution: true) } label: {
                                Label("Share this card", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(ReadingButtonStyle(prominent: false))
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Full year in review", systemImage: "sparkles").font(ReadingStyle.title(.title2))
                        Text("Unlock your longest streak, favorite genre, book of the year and high-resolution sharing with BookTrace Pro.")
                            .font(.subheadline).foregroundStyle(ReadingStyle.secondary)
                        Button("Explore BookTrace Pro") { showsPaywall = true }.buttonStyle(ReadingButtonStyle(prominent: false))
                    }
                    .readingCard()
                }
            }
            .padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .readingBackground()
        .navigationTitle("Year in review")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { workspace.load() }
        .task(id: workspace.yearInReview.bookOfYear?.id) {
            if let book = workspace.yearInReview.bookOfYear ?? workspace.yearInReview.fastestBook {
                await palettes.resolve(for: book)
            }
        }
        .sheet(isPresented: $showsPaywall) { PaywallView() }
        .sheet(item: $sharedCard) { artifact in
            NavigationStack {
                VStack(spacing: 24) {
                    Image(uiImage: artifact.image).resizable().scaledToFit().clipShape(.rect(cornerRadius: 20))
                        .accessibilityLabel("Your reading year card")
                    ShareLink(item: artifact.url, preview: SharePreview("My year in books", image: Image(uiImage: artifact.image))) {
                        Label("Share image", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(ReadingButtonStyle())
                }
                .padding(24).readingBackground().navigationTitle("Your reading year card")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { sharedCard = nil } } }
            }
        }
        .alert("Could not prepare image", isPresented: $shareError) { Button("OK", role: .cancel) {} }
    }

    @MainActor private func prepareImage(_ kind: ReviewCardKind, highResolution: Bool) {
        guard kind == .summary && !highResolution || entitlementStore.isPro else {
            showsPaywall = true
            return
        }
        let renderer = ImageRenderer(content: ReviewArtwork(kind: kind, summary: workspace.yearInReview, palette: palette, locale: locale)
            .environment(\.locale, locale).environment(\.colorScheme, .light).dynamicTypeSize(.large))
        renderer.scale = highResolution ? 4 : 2
        guard let image = renderer.uiImage, let data = image.pngData() else { shareError = true; return }
        do {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("BookTrace-year-review", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("BookTrace-\(workspace.selectedYear)-\(kind.rawValue)-\(UUID().uuidString).png")
            try data.write(to: url, options: .atomic)
            sharedCard = ReviewShareImage(url: url, image: image)
        } catch { shareError = true }
    }
}

private struct ReviewShareImage: Identifiable {
    let url: URL
    let image: UIImage
    var id: URL { url }
}

private enum ReviewCardKind: String, CaseIterable, Identifiable {
    case summary, streak, genre, favorite, pace
    var id: String { rawValue }
}

/// The same static, palette-driven artwork is used in the screen and in PNG
/// exports, so sharing never depends on an asynchronous image finishing first.
private struct ReviewArtwork: View {
    let kind: ReviewCardKind
    let summary: YearInReview
    let palette: BookPalette
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(verbatim: "BookTrace").font(.system(size: 17, weight: .medium, design: .serif))
                Spacer()
                Image(systemName: "book.pages").font(.title2.weight(.light))
            }
            .foregroundStyle(.white.opacity(0.85))
            Spacer(minLength: 4)
            Text(verbatim: String(summary.year)).font(.system(size: 72, weight: .regular, design: .serif))
                .foregroundStyle(palette.glow)
            artworkContent
            Spacer(minLength: 4)
            Rectangle().fill(.white.opacity(0.25)).frame(height: 1)
            Text("A year between the pages").font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(28)
        .frame(width: 320, height: 460, alignment: .leading)
        .foregroundStyle(.white)
        .background {
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: palette.atmosphere(.dark), startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(palette.halo.opacity(0.15)).frame(width: 230, height: 230).blur(radius: 35).offset(x: 85, y: -45)
            }
        }
        .clipShape(.rect(cornerRadius: 24))
        .dynamicTypeSize(.large)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var artworkContent: some View {
        switch kind {
        case .summary:
            Text("My year in books").font(.system(size: 29, weight: .regular, design: .serif))
            VStack(alignment: .leading, spacing: 9) {
                artworkMetric(summary.totalBooks.formatted(.number.locale(locale)), label: "Books finished")
                artworkMetric(summary.totalPages.formatted(.number.locale(locale)), label: "Pages read")
                artworkMetric(DurationFormatter.compact(seconds: summary.totalSeconds, locale: locale), label: "Time read")
            }
        case .streak:
            Text("One day, then another").font(.system(size: 27, weight: .regular, design: .serif))
            Text(summary.longestStreak, format: .number).font(.system(size: 54, weight: .medium, design: .rounded))
            Text("Longest reading streak").font(.system(size: 17))
        case .genre:
            Text("The world I returned to").font(.system(size: 27, weight: .regular, design: .serif))
            Text(summary.topGenre?.capitalized ?? String(localized: "Still discovering"))
                .font(.system(size: 36, weight: .medium, design: .serif)).lineLimit(3).minimumScaleFactor(0.7)
            Text("Most-read genre").font(.system(size: 17))
        case .favorite:
            Text("My book of the year").font(.system(size: 27, weight: .regular, design: .serif))
            bookText(summary.bookOfYear, empty: "Rate a finished book to find your favorite.")
        case .pace:
            Text("The pages flew by").font(.system(size: 27, weight: .regular, design: .serif))
            bookText(summary.fastestBook, empty: "Your next reading session starts the story.")
            Text("Fastest recorded reading pace").font(.system(size: 14))
        }
    }

    private func artworkMetric(_ value: String, label: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(value).font(.system(size: 23, weight: .medium, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 13)).foregroundStyle(.white.opacity(0.8))
        }
    }

    @ViewBuilder private func bookText(_ book: BookReference?, empty: LocalizedStringKey) -> some View {
        if let book {
            Text(book.title).font(.system(size: 29, weight: .medium, design: .serif)).lineLimit(4).minimumScaleFactor(0.6)
            Text(book.author).font(.system(size: 15)).foregroundStyle(.white.opacity(0.8)).lineLimit(2)
        } else { Text(empty).font(.system(size: 20, design: .serif)).foregroundStyle(.white.opacity(0.8)) }
    }
}

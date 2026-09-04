//
//  LibraryViews.swift
//  Books
//
//  Created by Semih TAKILAN on 04.09.2026.
//

import Models
import NavigatorUI
import SwiftUI

// MARK: - Seri

/// Üst üste okunan günler ve son bir haftanın özeti.
///
/// Bilinçli olarak küçük: kütüphanenin başında koca bir kart olsaydı ekranın
/// asıl işini — kitabı — aşağı iterdi. Amaç övünmek değil, dün okuduğunu
/// hatırlatmak.
struct ReadingStreakStrip: View {
    let days: Int
    /// Yedi gün, en eskiden bugüne.
    let activity: [Bool]

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                if days > 0 {
                    Text("\(days) days in a row")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ReadingStyle.ink)
                } else {
                    Text("Start a streak today")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ReadingStyle.ink)
                }
                Text("The last seven days")
                    .font(.caption2)
                    .foregroundStyle(ReadingStyle.secondary)
            }

            Spacer(minLength: 8)

            HStack(spacing: 7) {
                ForEach(Array(activity.enumerated()), id: \.offset) { index, didRead in
                    Circle()
                        .fill(didRead ? ReadingStyle.accent : ReadingStyle.line)
                        .frame(width: 9, height: 9)
                        // Bugün her hâlükârda işaretli: seri kırılmadan önce
                        // "bugün henüz boş" hissi verilmek isteniyor.
                        .overlay {
                            if index == activity.count - 1 {
                                Circle().strokeBorder(ReadingStyle.accent, lineWidth: 1.5)
                                    .frame(width: 15, height: 15)
                            }
                        }
                }
            }
            .padding(.trailing, 3)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(ReadingStyle.surface, in: .rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(ReadingStyle.line, lineWidth: 0.7) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(days > 0 ? "\(days) days in a row" : "Start a streak today")
        .accessibilityValue("\(activity.filter { $0 }.count) of the last 7 days")
    }
}

// MARK: - Okunan kitap kartı

/// Kütüphanenin en üstündeki kart: okunan kitap, ilerlemesi ve tek bir eylem.
struct NowReadingCard: View {
    let entry: LibraryEntry

    var body: some View {
        NowReadingCardBody(entry: entry)
            .bookAtmosphere(entry.book)
    }
}

private struct NowReadingCardBody: View {
    let entry: LibraryEntry

    @Environment(\.navigator) private var navigator
    @Environment(\.bookPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            identity
            progress
            actions
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 28)
                .fill(LinearGradient(colors: [palette.wash(colorScheme), palette.washEdge(colorScheme)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(palette.accent(colorScheme).opacity(0.16), lineWidth: 1)
        }
    }

    private var identity: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 18))

        return Button {
            navigator.navigate(to: BooksDestinations.entryDetail(entry))
        } label: {
            layout {
                BookVolumeView(book: entry.book, height: 148, progress: entry.progressFraction)

                VStack(alignment: .leading, spacing: 7) {
                    ReadingEyebrow(title: "NOW READING")
                    Text(entry.book.title)
                        .font(.system(.title3, design: .serif, weight: .medium))
                        .foregroundStyle(ReadingStyle.ink)
                        .modifier(BookTextLines(count: 3))
                    if !entry.book.author.isEmpty {
                        Text(entry.book.author)
                            .font(.caption)
                            .foregroundStyle(ReadingStyle.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens book details")
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 8) {
            TintedProgressBar(fraction: entry.progressFraction ?? 0,
                              tint: palette.accent(colorScheme),
                              track: ReadingStyle.ink.opacity(0.10))

            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(progressLabel)
                    Spacer(minLength: 8)
                    if let remaining { Text(remaining) }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(progressLabel)
                    if let remaining { Text(remaining) }
                }
            }
            .font(.caption)
            .foregroundStyle(ReadingStyle.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reading progress")
        .accessibilityValue("\(entry.progressPercentage ?? 0)% complete")
    }

    private var actions: some View {
        Button {
            navigator.navigate(to: BooksDestinations.readingSession(entry))
        } label: {
            Label("Continue reading", systemImage: "play.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(palette.accent(colorScheme), in: .capsule)
                .foregroundStyle(palette.onAccent(colorScheme))
        }
        .buttonStyle(.plain)
    }

    private var progressLabel: LocalizedStringKey {
        guard let total = entry.effectivePageCount else { return "Add a page count to track progress" }
        switch entry.progressType {
        case .pages:      return "\(entry.currentPage) of \(total) pages"
        case .percentage: return "\(entry.progressPercentage ?? 0)% of \(total) pages"
        }
    }

    private var remaining: LocalizedStringKey? {
        guard let seconds = entry.estimatedRemainingSeconds else { return nil }
        let formatted = DurationFormatter.compact(seconds: seconds, locale: locale)
        return entry.hasPersonalizedSpeed ? "~\(formatted) left" : "~\(formatted) left (estimate)"
    }
}

// MARK: - Raf karesi

/// Rafta bir kitap: kapak önce, başlık sonra.
///
/// Kütüphane daha önce tam genişlikte satırlardan oluşuyordu ve ekranda üç
/// kitap zor görünüyordu. Kapak, bir kitabı tanımanın en hızlı yolu; ızgara
/// aynı yükseklikte dokuz kitap gösteriyor.
struct ShelfBookTile: View {
    let entry: LibraryEntry
    let width: CGFloat

    var body: some View {
        ShelfBookTileBody(entry: entry, width: width)
            .bookAtmosphere(entry.book)
    }
}

private struct ShelfBookTileBody: View {
    let entry: LibraryEntry
    let width: CGFloat

    @Environment(\.bookPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            BookVolumeView(
                book: entry.book,
                height: BookVolumeView.height(fittingWidth: width),
                progress: entry.readingStatus == .reading ? entry.progressFraction : nil
            )
            .overlay(alignment: .bottomLeading) { badge }

            Text(entry.book.title)
                .font(.system(.footnote, design: .serif, weight: .medium))
                .foregroundStyle(ReadingStyle.ink)
                .modifier(BookTextLines(count: 2))
            if !entry.book.author.isEmpty {
                Text(entry.book.author)
                    .font(.caption2)
                    .foregroundStyle(ReadingStyle.secondary)
                    .modifier(BookTextLines(count: 1))
            }
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .combine)
        // Kitap başlığı kullanıcı verisi; çeviri anahtarı olarak kullanılamaz.
        .accessibilityLabel(Text(verbatim: entry.book.title) + Text(verbatim: ", ") + Text(entry.readingStatus.titleKey))
        // Yüzde yalnızca okunmakta olan kitapta anlamlı; diğerlerinde durum
        // zaten etikette geçiyor.
        .accessibilityValue(spokenProgress)
    }

    /// Kapağın köşesinde durumun tek bakışta okunan işareti.
    @ViewBuilder
    private var badge: some View {
        Group {
            if entry.readingStatus == .reading, let percentage = entry.progressPercentage {
                Text("\(percentage)%")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(palette.onAccent(colorScheme))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(palette.accent(colorScheme), in: .capsule)
            } else {
                Image(systemName: entry.readingStatus.systemImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(.black.opacity(0.55), in: .circle)
            }
        }
        .padding(6)
        .accessibilityHidden(true)
    }

    private var spokenProgress: Text {
        guard entry.readingStatus == .reading, let percentage = entry.progressPercentage else {
            return Text(verbatim: "")
        }
        return Text("\(percentage)% complete")
    }
}

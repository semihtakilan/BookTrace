//
//  ReadingHistoryView.swift
//  Profile
//
//  Created by Semih TAKILAN on 06.09.2026.
//

import SwiftUI
import NavigatorUI

struct ReadingHistoryView: View {
    let day: Date?
    @Environment(ProfileViewModel.self) private var viewModel
    @Environment(LibraryChangeNotifier.self) private var libraryChangeNotifier

    var body: some View {
        let days = viewModel.historyDays(on: day)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if days.isEmpty {
                    ContentUnavailableView("Nothing recorded yet.", systemImage: "book.closed")
                } else {
                    ForEach(days) { group in
                        VStack(alignment: .leading, spacing: 16) {
                            Text(group.date, format: .dateTime.weekday(.wide).month(.abbreviated).day().year())
                                .font(ReadingStyle.title(.title3))
                                .accessibilityAddTraits(.isHeader)
                            ForEach(Array(group.sessions.enumerated()), id: \.element.id) { index, session in
                                if index > 0 { Divider().overlay(ReadingStyle.line) }
                                ReadingSessionLink(session: session, showsDate: false)
                            }
                        }
                        .readingCard()
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .readingBackground()
        .navigationTitle("Reading history")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { viewModel.load() }
        .onChange(of: libraryChangeNotifier.revision) { _, _ in viewModel.load() }
    }
}

/// A reading session always leads back to its book, including from a selected day.
struct ReadingSessionLink: View {
    let session: RecentReadingSession
    var showsDate = true

    @Environment(\.navigator) private var navigator
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button { navigator.navigate(to: ProfileDestinations.bookDetail(session.book)) } label: {
            HStack(alignment: .center, spacing: 14) {
                BookVolumeView(book: session.book, height: 54, progress: nil)
                    .bookAtmosphere(session.book)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(session.bookTitle)
                        .font(.system(.subheadline, design: .serif, weight: .medium))
                        .modifier(BookTextLines(count: 2))
                        .foregroundStyle(ReadingStyle.ink)
                    let layout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 3))
                        : AnyLayout(HStackLayout(spacing: 6))
                    layout {
                        if showsDate {
                            Text(session.startDate, format: .dateTime.day().month(.abbreviated))
                        } else {
                            Text(session.startDate, format: .dateTime.hour().minute())
                        }
                        if !dynamicTypeSize.isAccessibilitySize { Text(verbatim: "·") }
                        Text("\(session.pagesRead) pages")
                    }
                    .font(.caption).foregroundStyle(ReadingStyle.secondary)
                    Text(DurationFormatter.compact(seconds: session.durationSeconds, locale: locale))
                        .font(.caption.weight(.medium).monospacedDigit())
                        .foregroundStyle(ReadingStyle.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ReadingStyle.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 5)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Take a closer look")
    }
}

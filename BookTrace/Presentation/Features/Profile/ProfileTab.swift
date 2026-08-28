//
//  ProfileTab.swift
//  Profile
//
//  Created by Semih TAKILAN on 07.08.2026.
//

import SwiftUI
import NavigatorUI
import Models

struct ProfileTab: View {
    private let viewModel: ProfileViewModel

    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ManagedNavigationStack {
            ProfileContentView(viewModel: viewModel)
        }
    }
}

private struct ProfileContentView: View {
    @Bindable var viewModel: ProfileViewModel

    @Environment(\.navigator) private var navigator
    @Environment(AppRouteTypeManager.self) private var routeManager
    @Environment(LibraryChangeNotifier.self) private var libraryChangeNotifier
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Group {
            if viewModel.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle(settings.localized("Profile"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    navigator.navigate(to: ProfileDestinations.settings)
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .errorAlert($viewModel.error)
        .onAppear { viewModel.load() }
        .onChange(of: libraryChangeNotifier.revision) { _, _ in viewModel.load() }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No reading stats yet", systemImage: "chart.bar")
        } description: {
            Text("Add a book to your library and record a reading session — your stats will show up here.")
        } actions: {
            Button("Go to Explore") {
                routeManager.selectedTab = .explore
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryTiles
                readingActivity
                pace
                breakdown(
                    title: "Reading Status",
                    rows: viewModel.statusBreakdown.map {
                        ($0.status.titleKey, $0.status.systemImage, $0.count)
                    }
                )
                breakdown(
                    title: "Ownership",
                    rows: viewModel.ownershipBreakdown.map {
                        ($0.status.titleKey, $0.status.systemImage, $0.count)
                    }
                )
                recentSessions
            }
            .padding()
        }
    }

    // MARK: - Bölümler

    private var summaryTiles: some View {
        HStack(spacing: 12) {
            SummaryTile(value: "\(viewModel.bookCount)", caption: "In Library", systemImage: "books.vertical")
            SummaryTile(value: "\(viewModel.readingCount)", caption: "Reading", systemImage: "book")
            SummaryTile(value: "\(viewModel.finishedCount)", caption: "Finished", systemImage: "checkmark.seal")
        }
    }

    private var readingActivity: some View {
        ProfileCard(title: "Reading Activity") {
            if viewModel.sessionCount == 0 {
                Text("No reading sessions recorded yet. Start Reading Mode on a book to track your time.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                LabeledContent("Time read", value: DurationFormatter.compact(seconds: viewModel.totalReadSeconds))
                Divider()
                LabeledContent("Pages read", value: "\(viewModel.totalPagesRead)")
                Divider()
                LabeledContent("Sessions", value: "\(viewModel.sessionCount)")

                if let remaining = viewModel.estimatedRemainingSeconds {
                    Divider()
                    LabeledContent("Left to finish", value: "~\(DurationFormatter.compact(seconds: remaining))")
                }
            }
        }
    }

    /// Faz 7'deki hız tahmininin kütüphane geneli karşılığı.
    private var pace: some View {
        ProfileCard(title: "Your Pace") {
            if let secondsPerPage = viewModel.secondsPerPage {
                LabeledContent(
                    "Per page",
                    value: DurationFormatter.compact(seconds: Int(secondsPerPage.rounded()))
                )
                if let pagesPerHour = viewModel.pagesPerHour {
                    Divider()
                    LabeledContent("Per hour", value: "\(pagesPerHour) pages")
                }
                Text("Measured from your own sessions. Time estimates get more accurate the more you read.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                LabeledContent(
                    "Per page",
                    value: DurationFormatter.compact(seconds: Int(ReadingSpeedEstimator.defaultSecondsPerPage))
                )
                Text("This is the starting assumption. After your first reading session it is replaced by your own measured pace.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    private func breakdown(title: LocalizedStringKey, rows: [(LocalizedStringKey, String, Int)]) -> some View {
        ProfileCard(title: title) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { Divider() }
                LabeledContent {
                    Text(row.2, format: .number)
                } label: {
                    Label(row.0, systemImage: row.1)
                }
            }
        }
    }

    private var recentSessions: some View {
        ProfileCard(title: "Recent Sessions") {
            if viewModel.recentSessions.isEmpty {
                Text("Nothing recorded yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(viewModel.recentSessions.enumerated()), id: \.element.id) { index, session in
                    if index > 0 { Divider() }
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.bookTitle)
                                .font(.subheadline)
                                .lineLimit(1)
                            Text(session.startDate, format: .dateTime.day().month().year())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(DurationFormatter.compact(seconds: session.durationSeconds))
                                .font(.subheadline.monospacedDigit())
                            Text("\(session.pagesRead) pages")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct SummaryTile: View {
    let value: String
    let caption: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
    }
}

private struct ProfileCard<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
    }
}

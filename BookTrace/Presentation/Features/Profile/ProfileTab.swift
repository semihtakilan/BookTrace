import SwiftUI
import NavigatorUI
import Models

struct ProfileTab: View {
    let viewModel: ProfileViewModel

    var body: some View {
        ManagedNavigationStack { ProfileContentView(viewModel: viewModel) }
    }
}

private struct ProfileContentView: View {
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.navigator) private var navigator
    @Environment(AppRouteTypeManager.self) private var routeManager
    @Environment(LibraryChangeNotifier.self) private var libraryChangeNotifier
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ReadingPageHeader(eyebrow: "ONE PAGE AT A TIME", title: "Your reading story", subtitle: "Small moments. Lasting impressions.")
                if viewModel.isEmpty {
                    ReadingEmptyState(symbol: "leaf", title: "Let your story grow.",
                                      message: "Your time, your pages, your progress. Add a book and your reading story begins here.",
                                      actionTitle: "Find your first book") { routeManager.selectedTab = .explore }
                } else {
                    readingActivity
                    summaryTiles
                    weeklyActivity
                    pace
                    recentSessions
                    breakdown(title: "Reading Status", rows: viewModel.statusBreakdown.map { ($0.status.titleKey, $0.status.systemImage, $0.count) })
                    breakdown(title: "Ownership", rows: viewModel.ownershipBreakdown.map { ($0.status.titleKey, $0.status.systemImage, $0.count) })
                }
            }
            .padding(24).padding(.bottom, 16)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .readingBackground()
        .navigationTitle("Journal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(verbatim: "BookTrace").font(.system(.headline, design: .serif))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { navigator.navigate(to: ProfileDestinations.settings) } label: {
                    Image(systemName: "gearshape").frame(width: 32, height: 32)
                }
                .accessibilityLabel("Settings")
            }
        }
        .errorAlert($viewModel.error)
        .onAppear { viewModel.load() }
        .onChange(of: libraryChangeNotifier.revision) { _, _ in viewModel.load() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { viewModel.load() } }
    }

    private var readingActivity: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                ReadingEyebrow(title: "TIME WELL SPENT")
                Spacer()
                Image(systemName: "sun.max").font(.title2.weight(.light)).foregroundStyle(ReadingStyle.accent)
                    .accessibilityHidden(true)
            }
            Text(DurationFormatter.compact(seconds: viewModel.totalReadSeconds, locale: locale))
                .font(.system(.largeTitle, design: .serif)).fontWeight(.medium)
                .foregroundStyle(ReadingStyle.ink)
                .accessibilityLabel("Time read")
                .accessibilityValue(DurationFormatter.compact(seconds: viewModel.totalReadSeconds, locale: locale))
            Text("Lost in a book. Found in your day.")
                .font(.subheadline).foregroundStyle(ReadingStyle.secondary)
            Rectangle().fill(ReadingStyle.accent.opacity(0.16)).frame(height: 1)
            HStack(alignment: .top, spacing: 28) {
                metric(value: viewModel.totalPagesRead, caption: "Pages read")
                metric(value: viewModel.sessionCount, caption: "Sessions")
            }
            if viewModel.sessionCount == 0 {
                Button("Start your first session") { routeManager.selectedTab = .books }
                    .buttonStyle(ReadingButtonStyle())
            }
        }
        .padding(24)
        .background(ReadingStyle.sage, in: .rect(cornerRadius: 26))
    }

    private func metric(value: Int, caption: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value, format: .number).font(.title2.weight(.medium).monospacedDigit())
            Text(caption).font(.caption).foregroundStyle(ReadingStyle.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var summaryTiles: some View {
        HStack(alignment: .top, spacing: 12) {
            SummaryTile(value: viewModel.bookCount, caption: "In Library", symbol: "books.vertical")
            SummaryTile(value: viewModel.readingCount, caption: "Reading", symbol: "book")
            SummaryTile(value: viewModel.finishedCount, caption: "Finished", symbol: "checkmark.seal")
        }
    }

    private var weeklyActivity: some View {
        VStack(alignment: .leading, spacing: 20) {
            ReadingSectionHeading(title: "The last seven days")
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(viewModel.recentDays) { day in
                    VStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(day.seconds > 0 ? ReadingStyle.accent : ReadingStyle.line)
                            .frame(height: day.seconds == 0 ? 4 : max(8, 84 * Double(day.seconds) / Double(maximumDailySeconds)))
                            .frame(height: 84, alignment: .bottom)
                        Text(day.date, format: .dateTime.weekday(.narrow))
                            .font(.caption).foregroundStyle(ReadingStyle.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(day.date, format: .dateTime.weekday(.wide).month().day()))
                    .accessibilityValue(DurationFormatter.compact(seconds: day.seconds, locale: locale))
                }
            }
            Text("Every little bit of reading counts.")
                .font(.caption).foregroundStyle(ReadingStyle.secondary)
        }
        .readingCard()
    }

    private var maximumDailySeconds: Int { max(1, viewModel.recentDays.map(\.seconds).max() ?? 1) }

    private var pace: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReadingSectionHeading(title: "Your Pace")
            if let seconds = viewModel.secondsPerPage {
                LabeledContent("Per page", value: DurationFormatter.compact(seconds: Int(seconds.rounded()), locale: locale))
                if let pages = viewModel.pagesPerHour { LabeledContent("Per hour") { Text("\(pages) pages") } }
                Text("Measured from your own sessions. Time estimates get more accurate the more you read.")
                    .font(.caption).foregroundStyle(ReadingStyle.secondary)
            } else {
                Text("Your rhythm will reveal itself.").font(ReadingStyle.title(.title3))
                Text("Record a reading session to discover your personal pace.")
                    .font(.subheadline).foregroundStyle(ReadingStyle.secondary)
            }
            if let remaining = viewModel.estimatedRemainingSeconds {
                Divider().overlay(ReadingStyle.line)
                LabeledContent("Left to finish", value: "~\(DurationFormatter.compact(seconds: remaining, locale: locale))")
                    .font(.subheadline)
                if viewModel.secondsPerPage == nil {
                    Text("An estimate until your first reading session.")
                        .font(.caption).foregroundStyle(ReadingStyle.secondary)
                }
            }
        }
        .readingCard()
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 18) {
            ReadingSectionHeading(title: "Recent Sessions")
            if viewModel.recentSessions.isEmpty {
                Text("Nothing recorded yet.").font(.subheadline).foregroundStyle(ReadingStyle.secondary)
            } else {
                ForEach(Array(viewModel.recentSessions.enumerated()), id: \.element.id) { index, session in
                    if index > 0 { Divider().overlay(ReadingStyle.line) }
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "bookmark").font(.subheadline).foregroundStyle(ReadingStyle.accent)
                            .frame(width: 36, height: 40).background(ReadingStyle.sage, in: .rect(cornerRadius: 10))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(session.bookTitle).font(.system(.subheadline, design: .serif, weight: .medium)).lineLimit(2)
                            Text(session.startDate, format: .dateTime.day().month(.abbreviated))
                                .font(.caption).foregroundStyle(ReadingStyle.secondary)
                            Text("\(session.pagesRead) pages").font(.caption).foregroundStyle(ReadingStyle.secondary)
                        }
                        Spacer(minLength: 0)
                        Text(DurationFormatter.compact(seconds: session.durationSeconds, locale: locale))
                            .font(.caption.weight(.medium).monospacedDigit())
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .readingCard()
    }

    private func breakdown(title: LocalizedStringKey, rows: [(LocalizedStringKey, String, Int)]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ReadingSectionHeading(title: title)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Label(row.0, systemImage: row.1).font(.subheadline).foregroundStyle(ReadingStyle.secondary)
                    Spacer()
                    Text(row.2, format: .number).font(.subheadline.monospacedDigit())
                }
            }
        }
        .readingCard()
    }
}

private struct SummaryTile: View {
    let value: Int
    let caption: LocalizedStringKey
    let symbol: String

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: symbol).font(.body).foregroundStyle(ReadingStyle.accent).accessibilityHidden(true)
            Text(value, format: .number).font(ReadingStyle.title(.title2)).monospacedDigit()
            Text(caption).font(.caption).foregroundStyle(ReadingStyle.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 18)
        .background(ReadingStyle.surface, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

import SwiftUI
import NavigatorUI
import Models

struct ProfileTab: View {
    let viewModel: ProfileViewModel

    var body: some View {
        ManagedNavigationStack { ProfileContentView(viewModel: viewModel) }
            .environment(viewModel)
    }
}

/// Günlük: okunan zamanın biriktiği yer.
///
/// Sayılar açılışta yerine oturuyor — istatistik ekranı, bir şey kazanılmış
/// gibi hissettirmeden okunmuş bir tablo olarak kalıyor.
private struct ProfileContentView: View {
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.navigator) private var navigator
    @Environment(AppRouteTypeManager.self) private var routeManager
    @Environment(LibraryChangeNotifier.self) private var libraryChangeNotifier
    @Environment(ReadingWorkspace.self) private var workspace
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var chartRevealed = false
    @State private var selectedActivityDay: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if Calendar.current.component(.month, from: Date()) == 12 {
                    NavigationLink { YearReviewView() } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Your reading year is ready", systemImage: "sparkles").font(.headline)
                            Text("Look back at the stories that stayed with you.").font(.subheadline)
                        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                            .background(ReadingStyle.sage, in: .rect(cornerRadius: 20))
                    }.buttonStyle(.plain)
                }
                VStack(alignment: .leading, spacing: 16) {
                    NavigationLink { ReadingGoalsView() } label: { Label("Reading goals", systemImage: "target") }
                    if let goal = workspace.goals.first(where: \.isActive) {
                        let progress = GoalProgressCalculator.progress(for: goal, entries: workspace.entries)
                        ProgressView(value: progress.fraction) { Text("\(progress.value) / \(goal.target)") + Text(" ") + Text(goal.metric.title) }
                            .tint(ReadingStyle.accent)
                    }
                    NavigationLink { ReadingInsightsView() } label: { Label("Reading insights", systemImage: "chart.xyaxis.line") }
                    NavigationLink { QuoteNotebookView() } label: { Label("Quote notebook", systemImage: "quote.opening") }
                    NavigationLink { YearReviewView() } label: { Label("Your year in books", systemImage: "sparkles") }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20).background(ReadingStyle.sage, in: .rect(cornerRadius: 20))
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
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .readingBackground()
        .navigationTitle("Journal")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
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
        .task {
            guard !reduceMotion else { chartRevealed = true; return }
            withAnimation(.spring(response: 0.75, dampingFraction: 0.82)) { chartRevealed = true }
        }
    }

    // MARK: - Toplam

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
                .contentTransition(reduceMotion ? .identity : .numericText())
                .accessibilityLabel("Time read")
                .accessibilityValue(DurationFormatter.compact(seconds: viewModel.totalReadSeconds, locale: locale))
            Text("Lost in a book. Found in your day.")
                .font(.subheadline).foregroundStyle(ReadingStyle.secondary)
            Rectangle().fill(ReadingStyle.accent.opacity(0.16)).frame(height: 1)
            metricLayout {
                metric(value: viewModel.totalPagesRead, caption: "Pages read")
                metric(value: viewModel.sessionCount, caption: "Sessions")
                metric(value: viewModel.streakDays, caption: "Day streak")
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
            CountingNumber(value: value)
                .font(.title2.weight(.medium).monospacedDigit())
            Text(caption).font(.caption).foregroundStyle(ReadingStyle.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var metricLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 20))
    }

    private var summaryTiles: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return layout {
            SummaryTile(value: viewModel.bookCount, caption: "In Library", symbol: "books.vertical")
            SummaryTile(value: viewModel.readingCount, caption: "Reading", symbol: "book")
            SummaryTile(value: viewModel.finishedCount, caption: "Finished", symbol: "checkmark.seal")
        }
    }

    // MARK: - Hafta

    private var weeklyActivity: some View {
        VStack(alignment: .leading, spacing: 18) {
            ReadingSectionHeading(title: "The last seven days")
            VStack(alignment: .leading, spacing: 6) {
                Text(DurationFormatter.compact(seconds: activitySeconds, locale: locale))
                    .font(ReadingStyle.title(.title2)).monospacedDigit()
                HStack(spacing: 8) {
                    Text("\(activityPages) pages")
                    Text(verbatim: "·")
                    Text("\(activitySessionCount) sessions")
                }
                .font(.caption).foregroundStyle(ReadingStyle.secondary)
            }
            .accessibilityElement(children: .combine)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(viewModel.recentDays.enumerated()), id: \.element.id) { index, day in
                    activityDayButton(day, index: index)
                }
            }

            if let day = selectedDay {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(day.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                            .font(.subheadline.weight(.semibold))
                        Spacer(minLength: 4)
                        Button("Reset") { selectedActivityDay = nil }
                            .font(.caption).frame(minHeight: 44)
                    }
                    if day.sessionCount == 0 {
                        Text("No sessions on this day.")
                            .font(.subheadline).foregroundStyle(ReadingStyle.secondary)
                    } else {
                        Button {
                            navigator.navigate(to: ProfileDestinations.readingHistory(day.date))
                        } label: {
                            HStack {
                                Text("View sessions")
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                        }
                        .buttonStyle(ReadingButtonStyle(prominent: false))
                    }
                }
            } else {
                Text("Tap a day to see your sessions.")
                    .font(.caption).foregroundStyle(ReadingStyle.secondary)
            }
        }
        .readingCard()
    }

    private func activityDayButton(_ day: ReadingDay, index: Int) -> some View {
        let isSelected = selectedActivityDay == day.date
        return Button {
            selectedActivityDay = isSelected ? nil : day.date
        } label: {
            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(day.seconds > 0
                          ? AnyShapeStyle(LinearGradient(colors: [ReadingStyle.accent.opacity(0.7), ReadingStyle.accent],
                                                         startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(ReadingStyle.line))
                    .frame(height: day.seconds == 0 ? 4 : max(8, 84 * Double(day.seconds) / Double(maximumDailySeconds)))
                    .frame(height: 84, alignment: .bottom)
                    .scaleEffect(y: chartRevealed ? 1 : 0.02, anchor: .bottom)
                    .animation(reduceMotion ? nil : ReadingMotion.progress.delay(Double(index) * 0.04),
                               value: chartRevealed)
                Text(day.date, format: .dateTime.weekday(.narrow))
                    .font(.caption.weight(isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? ReadingStyle.ink : ReadingStyle.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isSelected ? ReadingStyle.sage : .clear, in: .rect(cornerRadius: 10))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(day.date, format: .dateTime.weekday(.wide).month().day()))
        .accessibilityValue(Text(DurationFormatter.compact(seconds: day.seconds, locale: locale))
                            + Text(verbatim: ", ") + Text("\(day.pagesRead) pages"))
        .accessibilityHint("View sessions")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedDay: ReadingDay? {
        viewModel.recentDays.first { $0.date == selectedActivityDay }
    }

    private var activitySeconds: Int {
        selectedDay?.seconds ?? viewModel.recentDays.reduce(0) { $0 + $1.seconds }
    }

    private var activityPages: Int {
        selectedDay?.pagesRead ?? viewModel.recentDays.reduce(0) { $0 + $1.pagesRead }
    }

    private var activitySessionCount: Int {
        selectedDay?.sessionCount ?? viewModel.recentDays.reduce(0) { $0 + $1.sessionCount }
    }

    private var maximumDailySeconds: Int { max(1, viewModel.recentDays.map(\.seconds).max() ?? 1) }

    // MARK: - Hız

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

    // MARK: - Son oturumlar

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ReadingSectionHeading(title: "Recent Sessions")
                if !viewModel.sessionHistory.isEmpty {
                    Button("See all") { navigator.navigate(to: ProfileDestinations.readingHistory(nil)) }
                        .font(.caption.weight(.semibold)).frame(minHeight: 44)
                        .accessibilityLabel("Reading history")
                }
            }
            if viewModel.recentSessions.isEmpty {
                Text("Nothing recorded yet.").font(.subheadline).foregroundStyle(ReadingStyle.secondary)
            } else {
                ForEach(Array(viewModel.recentSessions.enumerated()), id: \.element.id) { index, session in
                    if index > 0 { Divider().overlay(ReadingStyle.line) }
                    ReadingSessionLink(session: session)
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
            CountingNumber(value: value)
                .font(ReadingStyle.title(.title2))
                .monospacedDigit()
            Text(caption).font(.caption).foregroundStyle(ReadingStyle.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 18)
        .background(ReadingStyle.surface, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

/// Açılışta sıfırdan değerine dönen sayı.
///
/// `contentTransition(.numericText())` rakamları tek tek çevirdiği için sayaç
/// etkisi tek bir değişiklikten çıkıyor; ara değerleri hesaplamaya gerek yok.
private struct CountingNumber: View {
    let value: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayed = 0

    var body: some View {
        Text(displayed, format: .number)
            .contentTransition(reduceMotion ? .identity : .numericText())
            .task(id: value) {
                guard !reduceMotion else {
                    displayed = value
                    return
                }
                displayed = 0
                withAnimation(.easeOut(duration: 0.9)) { displayed = value }
            }
            // Ekran okuyucu sayacın dönüşünü değil sonucu duymalı.
            .accessibilityLabel(Text(value, format: .number))
    }
}

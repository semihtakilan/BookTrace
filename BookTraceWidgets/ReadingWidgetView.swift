//
//  ReadingWidgetView.swift
//  BookTraceWidgets
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import BookTraceShared
import Models
import SwiftUI
import WidgetKit

enum ReadingWidgetKind { case book, streak, goal }

struct ReadingWidgetView: View {
    let entry: ReadingWidgetEntry
    let kind: ReadingWidgetKind
    @Environment(\.widgetFamily) private var family

    private var isAccessory: Bool { family == .accessoryCircular || family == .accessoryRectangular }
    private var accent: Color { Color(red: 0.42, green: 0.63, blue: 0.48) }
    private var destination: URL? {
        URL(string: !entry.isPro ? "booktrace://pro" : kind == .book ? "booktrace://library" : "booktrace://journal")
    }

    var body: some View {
        Group {
            if !entry.isPro {
                message("BookTrace Pro", detail: "Unlock widgets", icon: "lock.fill")
            } else if entry.storeUnavailable {
                message("Open BookTrace", detail: "Refresh your library", icon: "arrow.clockwise")
            } else {
                switch kind {
                case .book: book
                case .streak: streak
                case .goal: goal
                }
            }
        }
        .widgetURL(destination)
        .containerBackground(for: .widget) { Color(red: 0.08, green: 0.12, blue: 0.10) }
        .foregroundStyle(isAccessory ? Color.primary : .white)
        .tint(accent)
    }

    private func message(_ title: LocalizedStringKey, detail: LocalizedStringKey, icon: String) -> some View {
        VStack(alignment: isAccessory ? .center : .leading, spacing: 8) {
            Image(systemName: icon).font(isAccessory ? .body : .title2)
            if family != .accessoryCircular {
                Text(title).font(.headline)
                if !isAccessory { Text(detail).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isAccessory ? .center : .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    @ViewBuilder private var book: some View {
        if let book = entry.snapshot.book {
            HStack(spacing: 14) {
                if family == .systemMedium { cover.frame(width: 74, height: 112) }
                VStack(alignment: .leading, spacing: 7) {
                    if family == .systemSmall {
                        HStack {
                            cover.frame(width: 28, height: 40)
                            Spacer()
                            Image(systemName: "book.fill").foregroundStyle(accent)
                        }
                    } else {
                        Text("Now Reading").font(.caption).foregroundStyle(.secondary)
                    }
                    Text(book.book.title).font(.system(.headline, design: .serif)).lineLimit(2)
                    if family == .systemMedium {
                        Text(book.book.author).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    ProgressView(value: book.progressFraction ?? 0)
                    if let minutes = entry.snapshot.remainingMinutes {
                        Text("\(minutes) min left").font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text("Page \(book.currentPage)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        } else {
            message("Your next chapter", detail: "Start a book in your library", icon: "book.closed")
        }
    }

    private var cover: some View {
        Group {
            if let data = entry.coverData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 3).fill(accent.gradient)
                    Image(systemName: "book.closed.fill").foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .accessibilityHidden(true)
    }

    @ViewBuilder private var streak: some View {
        if family == .accessoryCircular {
            Gauge(value: Double(entry.snapshot.recentActivity.filter { $0 }.count), in: 0...7) {
                Image(systemName: "flame")
            } currentValueLabel: {
                Text(entry.snapshot.streak, format: .number)
            }
            .gaugeStyle(.accessoryCircular)
            .accessibilityLabel("Reading streak")
            .accessibilityValue(Text("\(entry.snapshot.streak) days"))
        } else {
            VStack(alignment: .leading, spacing: isAccessory ? 4 : 9) {
                Label("Reading Streak", systemImage: "flame.fill").font(.caption)
                Text("\(entry.snapshot.streak) days")
                    .font(isAccessory ? .headline : .system(.largeTitle, design: .rounded, weight: .semibold))
                    .minimumScaleFactor(0.7)
                HStack(spacing: 5) {
                    ForEach(Array(entry.snapshot.recentActivity.enumerated()), id: \.offset) { _, active in
                        Capsule().fill(active ? accent : Color.gray.opacity(0.3))
                            .frame(maxWidth: 20, minHeight: 5, maxHeight: 8)
                    }
                }
                .accessibilityLabel("Last seven days")
                if !isAccessory { Text("One chapter at a time").font(.caption2).foregroundStyle(.secondary) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var goal: some View {
        if let goal = entry.snapshot.goal {
            if family == .accessoryRectangular {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goalTitle(goal)).font(.headline)
                    ProgressView(value: entry.snapshot.goalFraction)
                    Text("\(entry.snapshot.goalValue) of \(goal.target)").font(.caption)
                }
                .accessibilityElement(children: .combine)
            } else if isAccessory {
                Gauge(value: entry.snapshot.goalFraction) {
                    Text(goalTitle(goal))
                } currentValueLabel: {
                    Text(entry.snapshot.goalFraction, format: .percent.precision(.fractionLength(0)))
                }
                .gaugeStyle(.accessoryCircular)
                .accessibilityValue(Text("\(entry.snapshot.goalValue) of \(goal.target)"))
            } else {
                let layout = family == .systemMedium ? AnyLayout(HStackLayout(spacing: 18)) : AnyLayout(VStackLayout(spacing: 8))
                layout {
                    ZStack {
                        Circle().stroke(.white.opacity(0.12), lineWidth: 8)
                        Circle().trim(from: 0, to: entry.snapshot.goalFraction)
                            .stroke(accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text(entry.snapshot.goalFraction, format: .percent.precision(.fractionLength(0)))
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                    }
                    .frame(width: family == .systemMedium ? 96 : 76, height: family == .systemMedium ? 96 : 76)
                    VStack(alignment: family == .systemMedium ? .leading : .center, spacing: 4) {
                        Text(goalTitle(goal)).font(.headline)
                        Text("\(entry.snapshot.goalValue) of \(goal.target)").font(.caption).foregroundStyle(.secondary)
                        Text(metricTitle(goal.metric)).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        } else {
            message("Set a reading goal", detail: "Choose a goal in Journal", icon: "target")
        }
    }

    private func goalTitle(_ goal: ReadingGoal) -> LocalizedStringKey {
        switch goal.period {
        case .daily: "Daily goal"
        case .weekly: "Weekly goal"
        case .monthly: "Monthly goal"
        case .yearly: "Yearly goal"
        }
    }

    private func metricTitle(_ metric: ReadingGoal.Metric) -> LocalizedStringKey {
        switch metric {
        case .minutes: "minutes"
        case .pages: "pages"
        case .books: "books"
        case .sessions: "sessions"
        }
    }
}

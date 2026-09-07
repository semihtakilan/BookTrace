//
//  ReadingInsightsView.swift
//  Release
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Charts
import Models
import SwiftUI

struct ReadingInsightsView: View {
    @Environment(ReadingWorkspace.self) private var workspace
    @Environment(EntitlementStore.self) private var entitlementStore
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @State private var showsPaywall = false
    @State private var showsPages = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ReadingYearSelector()
                if entitlementStore.isPro {
                    overview
                    annualActivity
                    monthlyReading
                    readingPace
                    readingHours
                    ratingDistribution
                    genreDistribution
                    finishedAverages
                } else {
                    VStack(spacing: 18) {
                        Image(systemName: "chart.xyaxis.line").font(.largeTitle).foregroundStyle(ReadingStyle.accent)
                        Text("Your reading, in detail").font(ReadingStyle.title(.title2))
                        Text("Explore your reading calendar, trends, favorite genres and personal pace with BookTrace Pro.")
                            .font(.subheadline).foregroundStyle(ReadingStyle.secondary).multilineTextAlignment(.center)
                        Button("Explore BookTrace Pro") { showsPaywall = true }.buttonStyle(ReadingButtonStyle())
                    }
                    .readingCard()
                }
            }
            .padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .readingBackground()
        .navigationTitle("Reading statistics")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { workspace.load() }
        .sheet(isPresented: $showsPaywall) { PaywallView() }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 16) {
            ReadingEyebrow(title: "TIME WELL SPENT")
            Text(DurationFormatter.compact(seconds: workspace.statistics.totalSeconds, locale: locale))
                .font(ReadingStyle.title()).monospacedDigit()
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 24) { summaryNumbers }
                VStack(alignment: .leading, spacing: 16) { summaryNumbers }
            }
            if workspace.statistics.totalSessions == 0 {
                Text("Your charts grow with every reading session.")
                    .font(.subheadline).foregroundStyle(ReadingStyle.secondary)
            }
        }
        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background(ReadingStyle.sage, in: .rect(cornerRadius: 24))
    }

    @ViewBuilder private var summaryNumbers: some View {
        number(workspace.statistics.completedBooks, title: "Finished")
        number(workspace.statistics.totalPages, title: "Pages read")
        number(workspace.statistics.totalSessions, title: "Sessions")
    }

    private func number(_ value: Int, title: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value, format: .number).font(.title2.weight(.medium).monospacedDigit())
            Text(title).font(.caption).foregroundStyle(ReadingStyle.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var annualActivity: some View {
        VStack(alignment: .leading, spacing: 16) {
            ReadingSectionHeading(title: "Reading calendar")
            Chart(workspace.statistics.heatmap) { day in
                RectangleMark(
                    xStart: .value("Week", weekStart(day.date)),
                    xEnd: .value("Week", weekStart(day.date).addingTimeInterval(6 * 86400)),
                    yStart: .value("Day", weekdayIndex(day.date)),
                    yEnd: .value("Day", weekdayIndex(day.date) + 0.86)
                )
                .foregroundStyle(day.sessions == 0 ? ReadingStyle.line : ReadingStyle.accent.opacity(intensity(day.seconds)))
                .cornerRadius(1)
                .accessibilityLabel(Text(day.date, format: .dateTime.month(.wide).day()))
                .accessibilityValue(Text(DurationFormatter.compact(seconds: day.seconds, locale: locale)))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.narrow))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [0.0, 2.0, 4.0, 6.0]) { value in
                    AxisValueLabel {
                        if let index = value.as(Double.self) {
                            Text(calendar.veryShortWeekdaySymbols[(Int(index) + calendar.firstWeekday - 1) % 7])
                        }
                    }
                }
            }
            .chartYScale(domain: 0...7, range: .plotDimension(startPadding: 0, endPadding: 0))
            .frame(height: 144)
            HStack(spacing: 6) {
                Text("Less")
                ForEach([0.2, 0.4, 0.6, 0.8, 1.0], id: \.self) { opacity in
                    RoundedRectangle(cornerRadius: 2).fill(ReadingStyle.accent.opacity(opacity)).frame(width: 11, height: 11)
                }
                Text("More")
            }
            .font(.caption2).foregroundStyle(ReadingStyle.secondary).accessibilityHidden(true)
        }
        .readingCard()
    }

    private var monthlyReading: some View {
        VStack(alignment: .leading, spacing: 16) {
            ReadingSectionHeading(title: "Monthly reading")
            Picker("Reading measure", selection: $showsPages) {
                Text("Time read").tag(false)
                Text("Pages read").tag(true)
            }
            .pickerStyle(.segmented)
            Chart(workspace.statistics.monthly) { month in
                BarMark(x: .value("Month", month.date, unit: .month),
                        y: .value(showsPages ? String(localized: "Pages read") : String(localized: "Hours read"),
                                  showsPages ? Double(month.pages) : Double(month.seconds) / 3600))
                .foregroundStyle(ReadingStyle.accent.gradient).cornerRadius(4)
            }
            .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in AxisValueLabel(format: .dateTime.month(.narrow)) } }
            .chartYAxisLabel(showsPages ? String(localized: "Pages read") : String(localized: "Hours read"))
            .frame(height: 190)
        }
        .readingCard()
    }

    private var readingPace: some View {
        VStack(alignment: .leading, spacing: 16) {
            ReadingSectionHeading(title: "Your reading pace")
            if workspace.statistics.pace.isEmpty {
                emptyChart("Record time and pages in a session to see your pace.")
            } else {
                Chart(workspace.statistics.pace) { point in
                    LineMark(x: .value("Month", point.date), y: .value("Minutes per page", point.secondsPerPage / 60))
                        .foregroundStyle(ReadingStyle.accent).symbol(.circle)
                }
                .chartYAxisLabel(String(localized: "Minutes per page"))
                .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated)) } }
                .frame(height: 180)
            }
            Text("Only sessions with both time and pages contribute to your pace.")
                .font(.caption).foregroundStyle(ReadingStyle.secondary)
        }
        .readingCard()
    }

    private var readingHours: some View {
        VStack(alignment: .leading, spacing: 16) {
            ReadingSectionHeading(title: "Your reading hours")
            Chart(workspace.statistics.hourly) { hour in
                BarMark(x: .value("Hour", hour.hour), y: .value("Minutes read", Double(hour.seconds) / 60))
                    .foregroundStyle(ReadingStyle.gold).cornerRadius(2)
            }
            .chartXScale(domain: -0.5...23.5)
            .chartXAxis { AxisMarks(values: [0, 6, 12, 18, 23]) }
            .chartYAxisLabel(String(localized: "Minutes read"))
            .frame(height: 180)
            Text("Sessions are grouped by their starting hour.")
                .font(.caption).foregroundStyle(ReadingStyle.secondary)
        }
        .readingCard()
    }

    private var ratingDistribution: some View {
        VStack(alignment: .leading, spacing: 16) {
            ReadingSectionHeading(title: "Your ratings")
            Chart(workspace.statistics.ratings) { rating in
                BarMark(x: .value("Rating", rating.rating), y: .value("Books", rating.count))
                    .foregroundStyle(ReadingStyle.gold.gradient).cornerRadius(5)
            }
            .chartXAxis { AxisMarks(values: [1, 2, 3, 4, 5]) { value in
                AxisValueLabel {
                    if let rating = value.as(Int.self) { Text("\(rating) ★") }
                }
            } }
            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                if let count = value.as(Double.self), count.rounded() == count { AxisValueLabel() }
            } }
            .frame(height: 170)
            Text("Ratings and genres reflect books finished in the selected year.")
                .font(.caption).foregroundStyle(ReadingStyle.secondary)
        }
        .readingCard()
    }

    private var genreDistribution: some View {
        VStack(alignment: .leading, spacing: 16) {
            ReadingSectionHeading(title: "The genres you explore")
            if workspace.statistics.genres.isEmpty {
                emptyChart("Finish a book with subject information to see your genres.")
            } else {
                Chart(Array(workspace.statistics.genres.prefix(8))) { genre in
                    BarMark(x: .value("Books", genre.count), y: .value("Genre", genre.name.capitalized))
                        .foregroundStyle(ReadingStyle.accent.gradient).cornerRadius(3)
                }
                .frame(height: CGFloat(min(workspace.statistics.genres.count, 8) * 40 + 30))
            }
        }
        .readingCard()
    }

    private var finishedAverages: some View {
        VStack(alignment: .leading, spacing: 16) {
            ReadingSectionHeading(title: "A finished book, on average")
            HStack {
                Text("Pages read")
                Spacer()
                if let pages = workspace.statistics.averageFinishedBookPages { Text(pages, format: .number.precision(.fractionLength(0))) }
                else { Text("Not enough data") }
            }
            HStack {
                Text("Time read")
                Spacer()
                if let seconds = workspace.statistics.averageFinishedBookSeconds {
                    Text(DurationFormatter.compact(seconds: Int(seconds), locale: locale))
                } else { Text("Not enough data") }
            }
            Text("Reading time includes recorded sessions only.").font(.caption).foregroundStyle(ReadingStyle.secondary)
        }
        .font(.subheadline).readingCard()
    }

    private func emptyChart(_ message: LocalizedStringKey) -> some View {
        Text(message).font(.subheadline).foregroundStyle(ReadingStyle.secondary).frame(maxWidth: .infinity, minHeight: 90)
    }

    private func weekStart(_ date: Date) -> Date { calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date }
    private func weekdayIndex(_ date: Date) -> Double {
        Double((calendar.component(.weekday, from: date) - calendar.firstWeekday + 7) % 7)
    }
    private func intensity(_ seconds: Int) -> Double { max(0.25, min(1, Double(seconds) / 3600)) }
}

struct ReadingYearSelector: View {
    @Environment(ReadingWorkspace.self) private var workspace

    var body: some View {
        @Bindable var workspace = workspace
        HStack {
            Text("Reading year").font(.subheadline).foregroundStyle(ReadingStyle.secondary)
            Spacer()
            Picker("Reading year", selection: $workspace.selectedYear) {
                ForEach((1900...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { year in
                    Text(verbatim: String(year)).tag(year)
                }
            }
            .pickerStyle(.menu).font(.headline)
        }
    }
}

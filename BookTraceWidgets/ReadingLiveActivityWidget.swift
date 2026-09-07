//
//  ReadingLiveActivityWidget.swift
//  BookTraceWidgets
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import ActivityKit
import BookTraceShared
import SwiftUI
import WidgetKit

struct ReadingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingActivityAttributes.self) { context in
            HStack(spacing: 16) {
                Image(systemName: "book.fill")
                    .font(.title)
                    .foregroundStyle(accent(context.attributes))
                VStack(alignment: .leading, spacing: 5) {
                    Text(context.attributes.bookTitle).font(.headline).lineLimit(1)
                    Text(context.attributes.author).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Label(context.state.clock.isPaused ? "Paused" : "Reading", systemImage: context.state.clock.isPaused ? "pause.fill" : "book")
                        .font(.caption2)
                }
                Spacer(minLength: 4)
                activityTimer(context.state.clock)
                    .font(.system(.title2, design: .rounded, weight: .medium))
                    .frame(maxWidth: 120)
            }
            .padding(18)
            .activityBackgroundTint(Color(hue: context.attributes.paletteHue, saturation: 0.35, brightness: 0.14))
            .activitySystemActionForegroundColor(.white)
            .foregroundStyle(.white)
            .widgetURL(URL(string: "booktrace://library"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.clock.isPaused ? "Paused" : "Reading", systemImage: "book.fill")
                        .foregroundStyle(accent(context.attributes)).font(.caption)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    activityTimer(context.state.clock).font(.headline).frame(maxWidth: 100)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(context.attributes.bookTitle).font(.headline).lineLimit(1)
                        if let count = context.state.pageCount, count > 0 {
                            ProgressView(value: min(1, Double(context.state.currentPage) / Double(count)))
                                .tint(accent(context.attributes))
                        }
                        Text("Page \(context.state.currentPage)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.clock.isPaused ? "pause.fill" : "book.fill")
                    .foregroundStyle(accent(context.attributes))
            } compactTrailing: {
                activityTimer(context.state.clock).frame(width: 58).font(.caption.monospacedDigit())
            } minimal: {
                Image(systemName: context.state.clock.isPaused ? "pause.fill" : "book.fill")
                    .foregroundStyle(accent(context.attributes))
            }
            .widgetURL(URL(string: "booktrace://library"))
            .keylineTint(accent(context.attributes))
        }
    }

    @ViewBuilder private func activityTimer(_ clock: ReadingActivityClock) -> some View {
        if let elapsed = clock.pausedElapsed {
            let total = Int(elapsed)
            Text(String(format: "%d:%02d", total / 60, total % 60)).monospacedDigit()
        } else {
            Text(timerInterval: clock.startDate...Date.distantFuture, countsDown: false)
                .monospacedDigit()
        }
    }

    private func accent(_ attributes: ReadingActivityAttributes) -> Color {
        Color(hue: attributes.paletteHue, saturation: min(0.7, max(0.25, attributes.paletteVibrancy)), brightness: 0.92)
    }
}

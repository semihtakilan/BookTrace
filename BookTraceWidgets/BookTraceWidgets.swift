//
//  BookTraceWidgets.swift
//  BookTraceWidgets
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import BookTraceShared
import SwiftUI
import WidgetKit

@main
struct BookTraceWidgets: WidgetBundle {
    var body: some Widget {
        NowReadingWidget()
        ReadingStreakWidget()
        ReadingGoalWidget()
        ReadingLiveActivityWidget()
    }
}

struct NowReadingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BookTrace.NowReading", provider: ReadingTimelineProvider()) { entry in
            ReadingWidgetView(entry: entry, kind: .book)
        }
        .configurationDisplayName("Now Reading")
        .description("Your current book and reading progress. Requires BookTrace Pro.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ReadingStreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BookTrace.ReadingStreak", provider: ReadingTimelineProvider()) { entry in
            ReadingWidgetView(entry: entry, kind: .streak)
        }
        .configurationDisplayName("Reading Streak")
        .description("A little reading, every day. Requires BookTrace Pro.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct ReadingGoalWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BookTrace.ReadingGoal", provider: ReadingTimelineProvider()) { entry in
            ReadingWidgetView(entry: entry, kind: .goal)
        }
        .configurationDisplayName("Reading Goal")
        .description("See how far your reading has taken you. Requires BookTrace Pro.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

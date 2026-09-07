//
//  ReadingTimelineProvider.swift
//  BookTraceWidgets
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import BookTraceShared
import Foundation
import ImageIO
import Models
import SwiftData
import UIKit
import WidgetKit

struct ReadingWidgetEntry: TimelineEntry {
    let date: Date
    let isPro: Bool
    let snapshot: ReadingWidgetSnapshot
    var coverData: Data?
    var storeUnavailable = false

    static func empty(isPro: Bool = false, date: Date = Date()) -> Self {
        Self(date: date, isPro: isPro, snapshot: ReadingWidgetSnapshot(entries: [], goals: [], now: date))
    }
}

struct ReadingTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadingWidgetEntry { .empty(isPro: true) }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (ReadingWidgetEntry) -> Void) {
        Task { @MainActor in completion(readEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<ReadingWidgetEntry>) -> Void) {
        Task { @MainActor in
            var entry = readEntry()
            if let url = entry.snapshot.book?.book.coverURL, entry.isPro {
                entry.coverData = await coverData(from: url)
            }
            let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date.addingTimeInterval(1_800)
            var entries = [entry]
            let defaults = UserDefaults(suiteName: BookTraceSharedConfiguration.appGroupIdentifier)
            if entry.isPro,
               let expiration = defaults?.object(forKey: BookTraceSharedConfiguration.proExpirationDefaultsKey) as? Date,
               expiration > entry.date {
                entries.append(.empty(date: expiration))
            }
            completion(Timeline(entries: entries, policy: .after(refresh)))
        }
    }

    @MainActor
    private func readEntry() -> ReadingWidgetEntry {
        let now = Date()
        let defaults = UserDefaults(suiteName: BookTraceSharedConfiguration.appGroupIdentifier)
        let isPro = BookTraceSharedConfiguration.hasWidgetAccess(
            enabled: defaults?.bool(forKey: BookTraceSharedConfiguration.proEntitlementDefaultsKey) ?? false,
            expiration: defaults?.object(forKey: BookTraceSharedConfiguration.proExpirationDefaultsKey) as? Date,
            now: now
        )
        guard isPro else { return .empty(date: now) }
        do {
            // Read-only configuration: the extension never migrates, syncs or
            // creates a second store. Opening the app performs those operations.
            let container = try LocalStore.makeWidgetContainer()
            let context = ModelContext(container)
            context.autosaveEnabled = false
            let entries = try context.fetch(FetchDescriptor<LocalLibraryEntryModel>()).map { $0.toDomain() }
            let goals = try context.fetch(FetchDescriptor<LocalReadingGoalModel>()).map { $0.toDomain() }
            return ReadingWidgetEntry(date: now, isPro: true, snapshot: ReadingWidgetSnapshot(entries: entries, goals: goals, now: now))
        } catch {
            var unavailable = ReadingWidgetEntry.empty(isPro: true, date: now)
            unavailable.storeUnavailable = true
            return unavailable
        }
    }

    private func coverData(from url: URL) async -> Data? {
        guard url.scheme?.lowercased() == "https" else { return nil }
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 8)
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              data.count < 5_000_000,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 240,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: thumbnail).jpegData(compressionQuality: 0.8)
    }
}

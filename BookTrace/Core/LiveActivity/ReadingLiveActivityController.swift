//
//  ReadingLiveActivityController.swift
//  LiveActivity
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import ActivityKit
import BookTraceShared
import Foundation
import Models

@MainActor
protocol ReadingLiveActivityControlling: AnyObject {
    func start(entry: LibraryEntry, palette: BookPalette, clock: ReadingActivityClock)
    func update(clock: ReadingActivityClock, currentPage: Int, pageCount: Int?)
    func end()
}

/// Activity writes are ordered so a quick pause/resume/save cannot leave the
/// lock screen with an older state. Denied system authorization never blocks reading.
@MainActor
final class ReadingLiveActivityController: ReadingLiveActivityControlling {
    private static var startupCleanup: Task<Void, Never>?
    // ActivityKit's Activity reference is not Sendable. Keep only its value ID
    // on the UI actor; each ordered worker resolves and uses its own reference.
    private var activityID: String?
    private var pendingUpdate: Task<Void, Never>?

    /// Call once during composition-root startup, before sessions can start.
    /// Session drafts are not restored after process termination, so an old
    /// Activity has no owner able to pause/save it. Capture IDs synchronously
    /// to ensure this cleanup can never end a subsequently started session.
    static func cleanupStaleActivities() {
        guard startupCleanup == nil else { return }
        let staleIDs = Set(Activity<ReadingActivityAttributes>.activities.map(\.id))
        startupCleanup = Task.detached {
            for activity in Activity<ReadingActivityAttributes>.activities where staleIDs.contains(activity.id) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    func start(entry: LibraryEntry, palette: BookPalette, clock: ReadingActivityClock) {
        guard activityID == nil, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = ReadingActivityAttributes(
            bookTitle: entry.book.title,
            author: entry.book.author,
            coverURLString: entry.book.coverURL?.absoluteString,
            paletteHue: palette.hue,
            paletteVibrancy: palette.vibrancy
        )
        let state = ReadingActivityAttributes.ContentState(clock: clock, currentPage: entry.currentPage, pageCount: entry.effectivePageCount)
        // A killed process cannot retain its session view model. Retire any old
        // activity before this session's ordered updates begin.
        let previousIDs = Set(Activity<ReadingActivityAttributes>.activities.map(\.id))
        do {
            activityID = try Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: nil), pushType: nil).id
            let startupCleanup = Self.startupCleanup
            pendingUpdate = Task.detached {
                await startupCleanup?.value
                for old in Activity<ReadingActivityAttributes>.activities where previousIDs.contains(old.id) {
                    await old.end(nil, dismissalPolicy: .immediate)
                }
            }
        } catch {
            // The session itself remains available, including on unsupported devices.
        }
    }

    func update(clock: ReadingActivityClock, currentPage: Int, pageCount: Int?) {
        guard let activityID else { return }
        let previous = pendingUpdate
        let state = ReadingActivityAttributes.ContentState(clock: clock, currentPage: currentPage, pageCount: pageCount)
        pendingUpdate = Task.detached {
            await previous?.value
            guard let activity = Activity<ReadingActivityAttributes>.activities.first(where: { $0.id == activityID }) else { return }
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func end() {
        guard let activityID else { return }
        self.activityID = nil
        let previous = pendingUpdate
        pendingUpdate = Task.detached {
            await previous?.value
            guard let activity = Activity<ReadingActivityAttributes>.activities.first(where: { $0.id == activityID }) else { return }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

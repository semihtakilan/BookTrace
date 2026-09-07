//
//  ReadingLiveActivityTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import BookTraceShared
import Foundation
import Models
import Testing
@testable import BookTrace

@MainActor
struct ReadingLiveActivityTests {
    @Test func freeSessionDoesNotStartAnActivity() {
        let activity = RecordingLiveActivity()
        let entry = makeEntry(pageCount: 100)
        let model = ReadingSessionViewModel(entry: entry, libraryRepository: LibraryRepositoryMock(), liveActivity: activity)
        model.start()
        #expect(model.isRunning)
        #expect(activity.starts == 0)
    }

    @Test func proSessionPropagatesPauseResumeAndDiscardInOrder() throws {
        let activity = RecordingLiveActivity()
        let clock = LiveActivityTestClock()
        let model = ReadingSessionViewModel(entry: makeEntry(pageCount: 100), libraryRepository: LibraryRepositoryMock(), now: { clock.now }, isProProvider: { true }, liveActivity: activity)
        model.start()
        clock.now.addTimeInterval(75)
        model.togglePause()
        #expect(try #require(activity.clocks.last).pausedElapsed == 75)
        clock.now.addTimeInterval(600)
        model.togglePause()
        clock.now.addTimeInterval(25)
        #expect(try #require(activity.clocks.last).elapsed(at: clock.now) == 100)
        model.discard()
        #expect(activity.starts == 1)
        #expect(activity.ends == 1)
    }

    @Test func savingEndsActivityOnlyAfterPersistenceSucceeds() {
        let activity = RecordingLiveActivity()
        let clock = LiveActivityTestClock()
        let entry = makeEntry(pageCount: 100)
        let repository = LibraryRepositoryMock()
        repository.storedEntries = [entry]
        let model = ReadingSessionViewModel(entry: entry, libraryRepository: repository, now: { clock.now }, isProProvider: { true }, liveActivity: activity)
        model.start()
        clock.now.addTimeInterval(60)
        model.pagesReadText = "5"
        repository.errorToThrow = LocalLibraryRepositoryError.entryNotFound(entry.id)
        model.save()
        #expect(activity.ends == 0)
        #expect(activity.clocks.last?.isPaused == true)
        repository.errorToThrow = nil
        model.save()
        #expect(model.didSave)
        #expect(activity.ends == 1)
    }
}

@MainActor private final class LiveActivityTestClock {
    var now = Date(timeIntervalSince1970: 1_800_000_000)
}

@MainActor private final class RecordingLiveActivity: ReadingLiveActivityControlling {
    var starts = 0
    var ends = 0
    var clocks: [ReadingActivityClock] = []
    func start(entry: LibraryEntry, palette: BookPalette, clock: ReadingActivityClock) {
        starts += 1
        clocks.append(clock)
    }
    func update(clock: ReadingActivityClock, currentPage: Int, pageCount: Int?) { clocks.append(clock) }
    func end() { ends += 1 }
}

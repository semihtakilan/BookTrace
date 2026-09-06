//
//  LibraryEntryDetailViewModelTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 06.09.2026.
//

import Foundation
import Models
import Testing
@testable import BookTrace

@MainActor
struct LibraryEntryDetailViewModelTests {
    @Test func progressValidationRejectsInvalidOrOutOfRangeInputAndAcceptsLocalizedDigits() {
        let entry = makeEntry(readingStatus: .reading, pageCount: 300, currentPage: 20)
        let viewModel = LibraryEntryDetailViewModel(entry: entry, libraryRepository: LibraryRepositoryMock())

        #expect(viewModel.page(forProgressInput: "") == nil)
        #expect(viewModel.page(forProgressInput: "twenty") == nil)
        #expect(viewModel.page(forProgressInput: "-1") == nil)
        #expect(viewModel.page(forProgressInput: "301") == nil)
        #expect(viewModel.page(forProgressInput: "25.5") == nil)
        #expect(viewModel.page(forProgressInput: " 25\n") == 25)
        #expect(viewModel.page(forProgressInput: "٢٥") == 25)
        #expect(viewModel.page(forProgressInput: "300") == 300)
    }

    @Test func percentageInputUsesTheReadersEditionAndRejectsValuesAboveOneHundred() {
        var entry = makeEntry(pageCount: 300)
        entry.pageCount = 200
        entry.progressType = .percentage
        let viewModel = LibraryEntryDetailViewModel(entry: entry, libraryRepository: LibraryRepositoryMock())

        #expect(viewModel.page(forProgressInput: "25") == 50)
        #expect(viewModel.page(forProgressInput: "100") == 200)
        #expect(viewModel.page(forProgressInput: "101") == nil)
    }

    @Test func unknownLengthStillAllowsRecordingACurrentPage() {
        let repository = LibraryRepositoryMock()
        let entry = makeEntry()
        repository.storedEntries = [entry]
        let viewModel = LibraryEntryDetailViewModel(entry: entry, libraryRepository: repository)

        #expect(viewModel.page(forProgressInput: "35") == 35)
        viewModel.update(currentPage: 35)
        #expect(viewModel.entry.currentPage == 35)
        #expect(viewModel.entry.readingStatus == .reading)
        viewModel.update(progressType: .percentage)
        #expect(viewModel.page(forProgressInput: "35") == nil)
    }

    @Test func correctingAFinishedBooksProgressReopensItWithoutChangingSessionHistory() {
        let repository = LibraryRepositoryMock()
        let session = ReadingSession(startDate: Date(), durationSeconds: 600, pagesRead: 10)
        let entry = makeEntry(readingStatus: .finished, pageCount: 300, sessions: [session])
        repository.storedEntries = [entry]
        let viewModel = LibraryEntryDetailViewModel(entry: entry, libraryRepository: repository)

        viewModel.update(currentPage: 200)

        #expect(viewModel.entry.currentPage == 200)
        #expect(viewModel.entry.readingStatus == .reading)
        #expect(viewModel.entry.readingSessions == [session])
    }

    @Test func failedProgressUpdatePreservesTheVisibleEntry() {
        let repository = LibraryRepositoryMock()
        let entry = makeEntry(readingStatus: .reading, pageCount: 300, currentPage: 20)
        repository.storedEntries = [entry]
        let viewModel = LibraryEntryDetailViewModel(entry: entry, libraryRepository: repository)
        repository.errorToThrow = LocalLibraryRepositoryError.entryNotFound(entry.id)

        viewModel.update(currentPage: 100)

        #expect(viewModel.entry.currentPage == 20)
        #expect(viewModel.error == .notInLibrary)
        repository.errorToThrow = nil
        viewModel.reload()
        #expect(viewModel.error == nil)
    }
}

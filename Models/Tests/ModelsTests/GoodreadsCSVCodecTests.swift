//
//  GoodreadsCSVCodecTests.swift
//  ModelsTests
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation
import Testing
@testable import Models

struct GoodreadsCSVCodecTests {
    @Test func importsActualGoodreadsQuotingMultilineNotesAndISBNWrapper() throws {
        let csv = "\u{FEFF}Book Id,Title,Author,ISBN13,My Rating,Number of Pages,Date Read,Exclusive Shelf,Private Notes\r\n"
            + "1,\"Title, with \"\"quotes\"\"\",Writer,\"=\"\"9780306406157\"\"\",5,300,2026/01/02,read,\"First line\nSecond line\"\r\n"
        let entry = try #require(GoodreadsCSVCodec.decode(csv).first)
        #expect(entry.id == "local:goodreads:1")
        #expect(entry.book.source == .local)
        #expect(entry.book.title == "Title, with \"quotes\"")
        #expect(entry.book.isbn13 == "9780306406157")
        #expect(entry.rating == 5)
        #expect(entry.currentPage == 300)
        #expect(entry.readingStatus == .finished)
        #expect(entry.finishedDate != nil)
        #expect(entry.notes == "First line\nSecond line")
    }

    @Test func exportedMetadataRoundTripsWithoutLosingCommasNewlinesOrCustomStatus() throws {
        let entry = LibraryEntry(book: BookReference(id: "ol:/works/123", title: "A, B\nC", authors: ["One", "Two"], pageCount: 100),
                                 readingStatus: .abandoned, ownershipStatus: .owned, currentPage: 20,
                                 categories: [Category(name: "Book Club")], rating: 3, notes: "Line 1\r\n\"Line 2\"", isFavorite: true)
        let decoded = try #require(GoodreadsCSVCodec.decode(GoodreadsCSVCodec.encode([entry])).first)
        #expect(decoded.id == entry.id)
        #expect(decoded.book.title == entry.book.title)
        #expect(decoded.book.authors == entry.book.authors)
        #expect(decoded.readingStatus == .abandoned)
        #expect(decoded.currentPage == 20)
        #expect(decoded.rating == 3)
        #expect(decoded.ownershipStatus == .owned)
        #expect(decoded.notes == entry.notes)
        #expect(decoded.isFavorite)
    }

    @Test func absentDatesRemainUnknownAndZeroMeansUnrated() throws {
        let entry = try #require(GoodreadsCSVCodec.decode("Title,My Rating,Exclusive Shelf\nUnknown,0,read\n").first)
        #expect(entry.rating == nil)
        #expect(entry.finishedDate == nil)
        #expect(entry.readingStatus == .finished)
    }

    @Test(arguments: ["America/Los_Angeles", "Europe/Istanbul", "Asia/Tokyo"])
    func civilDatesStayInTheReadersCalendarYear(timeZoneID: String) throws {
        let timeZone = try #require(TimeZone(identifier: timeZoneID))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let csv = "Title,Date Read,Date Added,Exclusive Shelf\nNew Year,2026/01/01,2025/12/31,read\n"
        let entry = try #require(GoodreadsCSVCodec.decode(csv, timeZone: timeZone).first)
        let finished = try #require(entry.finishedDate)
        #expect(calendar.dateComponents([.year, .month, .day], from: finished)
                == DateComponents(year: 2026, month: 1, day: 1))
        #expect(calendar.dateComponents([.year, .month, .day], from: entry.addedDate)
                == DateComponents(year: 2025, month: 12, day: 31))
        #expect(YearInReview(entries: [entry], year: 2026, calendar: calendar).totalBooks == 1)
        #expect(YearInReview(entries: [entry], year: 2025, calendar: calendar).totalBooks == 0)
        let exported = GoodreadsCSVCodec.encode([entry], timeZone: timeZone)
        #expect(exported.contains("2026/01/01,2025/12/31"))
        let roundTrip = try #require(GoodreadsCSVCodec.decode(exported, timeZone: timeZone).first)
        #expect(roundTrip.finishedDate == finished)
        #expect(roundTrip.addedDate == entry.addedDate)
    }

    @Test func identicalImportRowsAreIdempotentlyDeduplicated() throws {
        let csv = "Book Id,Title,Author\n1,One,A\n1,One,A\n\n"
        #expect(try GoodreadsCSVCodec.decode(csv).count == 1)
    }

    @Test func isbnTenIsConvertedToThirteenForNetworkResolution() throws {
        let entry = try #require(GoodreadsCSVCodec.decode("Title,ISBN\nOne,0306406152\n").first)
        #expect(entry.book.isbn13 == "9780306406157")
    }

    @Test func exportsProtectSpreadsheetFormulaCellsAndRestoreTheirText() throws {
        let entry = LibraryEntry(book: BookReference(id: "one", title: "=SUM(1,2)", authors: ["@author"]), notes: "  +formula")
        let csv = GoodreadsCSVCodec.encode([entry])
        #expect(csv.contains("'=SUM"))
        #expect(csv.contains("'@author"))
        let decoded = try #require(GoodreadsCSVCodec.decode(csv).first)
        #expect(decoded.book.title == entry.book.title)
        #expect(decoded.notes == "+formula")
    }

    @Test func brokenFilesReportErrorsBeforePartialImport() {
        #expect(throws: GoodreadsCSVCodec.CSVError.missingTitleColumn) {
            try GoodreadsCSVCodec.decode("Author\nWriter\n")
        }
        #expect(throws: GoodreadsCSVCodec.CSVError.malformedCSV) {
            try GoodreadsCSVCodec.decode("Title\n\"Unclosed\n")
        }
        #expect(throws: GoodreadsCSVCodec.CSVError.missingTitle(row: 3)) {
            try GoodreadsCSVCodec.decode("Title,Author\nValid,Writer\n,Writer\n")
        }
    }
}

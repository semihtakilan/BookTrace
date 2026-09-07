//
//  LocalLibraryEntryModel.swift
//  BookTraceShared
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation
import Models
import SwiftData

@Model
public final class LocalLibraryEntryModel {
    /// Synced physical-row identity, separate from the book's logical identity.
    /// Empty is a CloudKit-compatible migration default; initializers and the V1
    /// migration assign a distinct value once, before the row can be uploaded.
    public var rowID: String = ""
    public var bookID: String = ""
    public var title: String = ""
    public var authors: [String] = []
    public var coverURLString: String?
    public var sourcePageCount: Int?
    public var publishedDate: String?
    public var bookDescription: String?
    public var isbn13: String?
    public var subjects: [String] = []
    public var readingStatusRawValue: String = "toRead"
    public var ownershipStatusRawValue: String = "notOwned"
    public var progressTypeRawValue: String = "pages"
    public var pageCount: Int?
    public var currentPage: Int = 0
    public var addedDate: Date = Date(timeIntervalSince1970: 0)
    public var rating: Int?
    public var finishedDate: Date?
    public var notes: String?
    public var isFavorite: Bool = false
    public var modifiedDate: Date = Date(timeIntervalSince1970: 0)

    public var categories: [LocalCategoryModel]? = []
    @Relationship(deleteRule: .cascade, inverse: \LocalReadingSessionModel.libraryEntry)
    public var readingSessions: [LocalReadingSessionModel]? = []
    @Relationship(deleteRule: .cascade, inverse: \LocalQuoteModel.libraryEntry)
    public var quotes: [LocalQuoteModel]? = []

    public var categoryRecords: [LocalCategoryModel] { categories ?? [] }
    public var sessionRecords: [LocalReadingSessionModel] { readingSessions ?? [] }
    public var quoteRecords: [LocalQuoteModel] { quotes ?? [] }

    public init(entry: LibraryEntry, categories: [LocalCategoryModel] = []) {
        rowID = UUID().uuidString
        bookID = entry.id
        addedDate = entry.addedDate
        apply(entry, categories: categories)
        readingSessions = entry.readingSessions.map(LocalReadingSessionModel.init)
        quotes = entry.quotes.map(LocalQuoteModel.init)
    }

    public func apply(_ entry: LibraryEntry, categories: [LocalCategoryModel]) {
        title = entry.book.title
        authors = entry.book.authors
        coverURLString = entry.book.coverURL?.absoluteString
        sourcePageCount = entry.book.pageCount
        publishedDate = entry.book.publishedDate
        bookDescription = entry.book.description
        isbn13 = entry.book.isbn13
        subjects = entry.book.subjects
        readingStatusRawValue = entry.readingStatus.rawValue
        ownershipStatusRawValue = entry.ownershipStatus.rawValue
        progressTypeRawValue = entry.progressType.rawValue
        pageCount = entry.pageCount
        currentPage = entry.currentPage
        rating = entry.rating
        finishedDate = entry.finishedDate
        notes = entry.notes
        isFavorite = entry.isFavorite
        modifiedDate = Date()
        self.categories = categories
    }

    public func toDomain() -> LibraryEntry {
        LibraryEntry(
            book: BookReference(id: bookID, title: title, authors: authors,
                                coverURL: coverURLString.flatMap(URL.init(string:)), pageCount: sourcePageCount,
                                publishedDate: publishedDate, description: bookDescription, isbn13: isbn13, subjects: subjects),
            readingStatus: ReadingStatus(rawValue: readingStatusRawValue) ?? .toRead,
            ownershipStatus: OwnershipStatus(rawValue: ownershipStatusRawValue) ?? .notOwned,
            progressType: ProgressType(rawValue: progressTypeRawValue) ?? .pages,
            pageCount: pageCount, currentPage: currentPage,
            categories: categoryRecords.map { $0.toDomain() }.sorted { $0.name < $1.name },
            addedDate: addedDate, readingSessions: sessionRecords.map { $0.toDomain() }.sorted { $0.startDate < $1.startDate },
            rating: rating, finishedDate: finishedDate, notes: notes, isFavorite: isFavorite,
            quotes: quoteRecords.map { $0.toDomain() }.sorted { $0.createdDate < $1.createdDate }
        )
    }
}

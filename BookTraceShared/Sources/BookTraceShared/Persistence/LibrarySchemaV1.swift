//
//  LibrarySchemaV1.swift
//  BookTraceShared
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation
import Models
import SwiftData

public enum LibrarySchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        [LocalLibraryEntryModel.self, LocalReadingSessionModel.self, LocalCategoryModel.self]
    }

    @Model
    public final class LocalLibraryEntryModel {
        @Attribute(.unique) var bookID: String

        // MARK: Kitabın uzak metadata'sının anlık görüntüsü
        var title: String
        var authors: [String]
        var coverURLString: String?
        var sourcePageCount: Int?
        var publishedDate: String?
        var bookDescription: String?
        var isbn13: String?
        var subjects: [String]

        // MARK: Kullanıcıya ait okuma durumu
        var readingStatusRawValue: String
        var ownershipStatusRawValue: String
        var progressTypeRawValue: String
        var pageCount: Int?
        var currentPage: Int
        var addedDate: Date

        var categories: [LocalCategoryModel]

        @Relationship(deleteRule: .cascade, inverse: \LocalReadingSessionModel.libraryEntry)
        var readingSessions: [LocalReadingSessionModel]

        public init(entry: LibraryEntry, categories: [LocalCategoryModel]) {
            bookID = entry.book.id
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
            addedDate = entry.addedDate

            self.categories = categories
            readingSessions = entry.readingSessions.map(LocalReadingSessionModel.init)
        }

        /// Yalnızca kullanıcıya ait alanları günceller; oturumlar `appendSession` ile yönetilir.
        func apply(_ entry: LibraryEntry, categories: [LocalCategoryModel]) {
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

            self.categories = categories
        }

        func toDomain() -> LibraryEntry {
            LibraryEntry(
                book: BookReference(
                    id: bookID,
                    title: title,
                    authors: authors,
                    coverURL: coverURLString.flatMap(URL.init(string:)),
                    pageCount: sourcePageCount,
                    publishedDate: publishedDate,
                    description: bookDescription,
                    isbn13: isbn13,
                    subjects: subjects
                ),
                readingStatus: ReadingStatus(rawValue: readingStatusRawValue) ?? .toRead,
                ownershipStatus: OwnershipStatus(rawValue: ownershipStatusRawValue) ?? .notOwned,
                progressType: ProgressType(rawValue: progressTypeRawValue) ?? .pages,
                pageCount: pageCount,
                currentPage: currentPage,
                categories: categories
                    .map { $0.toDomain() }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
                addedDate: addedDate,
                readingSessions: readingSessions
                    .map { $0.toDomain() }
                    .sorted { $0.startDate < $1.startDate }
            )
        }
    }

    @Model
    public final class LocalReadingSessionModel {
        @Attribute(.unique) public var id: String
        var startDate: Date
        var durationSeconds: Int
        var pagesRead: Int

        /// `LocalLibraryEntryModel.readingSessions` ilişkisinin ters ucu.
        var libraryEntry: LocalLibraryEntryModel?

        public init(session: ReadingSession) {
            id = session.id
            startDate = session.startDate
            durationSeconds = session.durationSeconds
            pagesRead = session.pagesRead
        }

        func toDomain() -> ReadingSession {
            ReadingSession(
                id: id,
                startDate: startDate,
                durationSeconds: durationSeconds,
                pagesRead: pagesRead
            )
        }
    }

    @Model
    public final class LocalCategoryModel {
        @Attribute(.unique) public var id: String
        var name: String
        var colorHex: String?

        /// Aynı etiket birden çok kayda bağlanabilir; kayıt silinince etiket yaşamaya devam eder.
        @Relationship(deleteRule: .nullify, inverse: \LocalLibraryEntryModel.categories)
        var entries: [LocalLibraryEntryModel] = []

        public init(category: Models.Category) {
            id = category.id
            name = category.name
            colorHex = category.colorHex
        }

        func apply(_ category: Models.Category) {
            name = category.name
            colorHex = category.colorHex
        }

        func toDomain() -> Models.Category {
            Models.Category(id: id, name: name, colorHex: colorHex)
        }
    }
}

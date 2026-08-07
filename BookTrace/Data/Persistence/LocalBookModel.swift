//
//  LocalBookModel.swift
//  BookTrace
//

import Foundation
import Models
import SwiftData

/// SwiftData'ya özgü kalıcı model; Domain `Book` tipinden bilinçli olarak ayrıdır.
@Model
final class LocalBookModel {
    @Attribute(.unique) var id: String
    var title: String
    var authors: [String]
    var pageCount: Int
    var coverURLString: String?
    var publishedDate: String?
    var bookDescription: String?
    var isbn13: String?
    var statusRawValue: String
    var isFavorite: Bool
    var currentProgress: Int

    init(book: Book) {
        id = book.id
        title = book.title
        authors = book.authors
        pageCount = book.pageCount ?? 0
        coverURLString = book.coverURL?.absoluteString
        publishedDate = book.publishedDate
        bookDescription = book.description
        isbn13 = book.isbn13
        statusRawValue = book.status.rawValue
        isFavorite = book.isFavorite
        currentProgress = book.currentProgress
    }

    func apply(_ book: Book) {
        title = book.title
        authors = book.authors
        pageCount = book.pageCount ?? 0
        coverURLString = book.coverURL?.absoluteString
        publishedDate = book.publishedDate
        bookDescription = book.description
        isbn13 = book.isbn13
        statusRawValue = book.status.rawValue
        isFavorite = book.isFavorite
        currentProgress = book.currentProgress
    }

    func toDomain() -> Book {
        Book(
            id: id,
            title: title,
            authors: authors,
            pageCount: pageCount == 0 ? nil : pageCount,
            coverURL: coverURLString.flatMap(URL.init(string:)),
            publishedDate: publishedDate,
            description: bookDescription,
            isbn13: isbn13,
            status: ReadingStatus(rawValue: statusRawValue) ?? .toRead,
            isFavorite: isFavorite,
            currentProgress: currentProgress
        )
    }
}

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
    
    var ownershipRawValue: String
    var actualReadTime: TimeInterval
    var dynamicReadingSpeed: Double?
    var estimatedRemainingTime: TimeInterval?
    
    @Relationship(deleteRule: .nullify) var categories: [LocalCategoryModel]

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
        
        ownershipRawValue = book.ownership.rawValue
        actualReadTime = book.actualReadTime
        dynamicReadingSpeed = book.dynamicReadingSpeed
        estimatedRemainingTime = book.estimatedRemainingTime
        categories = book.categories.map { LocalCategoryModel(category: $0) }
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
        
        ownershipRawValue = book.ownership.rawValue
        actualReadTime = book.actualReadTime
        dynamicReadingSpeed = book.dynamicReadingSpeed
        estimatedRemainingTime = book.estimatedRemainingTime
        categories = book.categories.map { LocalCategoryModel(category: $0) }
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
            currentProgress: currentProgress,
            ownership: OwnershipStatus(rawValue: ownershipRawValue) ?? .notOwned,
            categories: categories.map { $0.toDomain() },
            actualReadTime: actualReadTime,
            dynamicReadingSpeed: dynamicReadingSpeed,
            estimatedRemainingTime: estimatedRemainingTime
        )
    }
}

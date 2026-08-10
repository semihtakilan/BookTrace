//
//  Book.swift
//  Models
//
//  Created by Semih TAKILAN on 31.07.2026.
//

import Foundation

public struct Book: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let title: String
    public let authors: [String]
    public let pageCount: Int?
    public let coverURL: URL?
    public let publishedDate: String?
    public let description: String?
    public let isbn13: String?
    public let status: ReadingStatus
    public let isFavorite: Bool
    public let currentProgress: Int

    public var author: String {
        authors.joined(separator: ", ")
    }

    public init(
        id: String,
        title: String,
        authors: [String] = [],
        pageCount: Int? = nil,
        coverURL: URL? = nil,
        publishedDate: String? = nil,
        description: String? = nil,
        isbn13: String? = nil,
        status: ReadingStatus = .toRead,
        isFavorite: Bool = false,
        currentProgress: Int = 0
    ) {
        self.id = id
        self.title = title
        self.authors = authors
        self.pageCount = pageCount
        self.coverURL = coverURL
        self.publishedDate = publishedDate
        self.description = description
        self.isbn13 = isbn13
        self.status = status
        self.isFavorite = isFavorite
        self.currentProgress = max(0, currentProgress)
    }
}

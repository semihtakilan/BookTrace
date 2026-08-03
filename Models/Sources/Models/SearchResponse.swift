//
//  SearchResponse.swift
//  Models
//
//  Created by Semih TAKILAN on 3.08.2026.
//

import Foundation

public struct SearchResponse: Codable, Sendable {
    public let numFound: Int
    public let start: Int
    public let docs: [BookSummary]
}

public struct BookSummary: Codable, Sendable, Identifiable, Hashable {
    public let key: String
    public let title: String
    public let authorName: [String]?
    public let coverId: Int?
    public let firstPublishYear: Int?
    public let isbn: [String]?

    public var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key, title, isbn
        case authorName = "author_name"
        case coverId = "cover_i"
        case firstPublishYear = "first_publish_year"
    }

    public var coverURL: URL? {
        guard let coverId else { return nil }
        return URL(string: "https://covers.openlibrary.org/b/id/\(coverId)-M.jpg")
    }
}

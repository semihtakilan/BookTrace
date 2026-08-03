//
//  Book.swift
//  Models
//
//  Created by Semih TAKILAN on 31.07.2026.
//

import Foundation

public struct Book: Codable, Sendable {
    public let title: String
    public let subtitle: String?
    public let authors: [BookAuthor]?
    public let publishers: [BookPublisher]?
    public let publishDate: String?
    public let numberOfPages: Int?
    public let subjects: [BookSubject]?
    public let cover: BookCover?
    public let identifiers: BookIdentifiers?
    public let url: String?
}

public struct BookAuthor: Codable, Sendable {
    public let name: String
    public let url: String?
}

public struct BookPublisher: Codable, Sendable {
    public let name: String
}

public struct BookSubject: Codable, Sendable {
    public let name: String
    public let url: String?
}

public struct BookCover: Codable, Sendable {
    public let small: String?
    public let medium: String?
    public let large: String?
}

public struct BookIdentifiers: Codable, Sendable {
    public let isbn10: [String]?
    public let isbn13: [String]?
    public let openlibrary: [String]?

    enum CodingKeys: String, CodingKey {
        case isbn10 = "isbn_10"
        case isbn13 = "isbn_13"
        case openlibrary
    }
}

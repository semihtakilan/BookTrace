//
//  SubjectResponse.swift
//  Models
//
//  Created by Semih TAKILAN on 3.08.2026.
//

import Foundation

public struct SubjectResponse: Codable, Sendable {
    public let key: String
    public let name: String
    public let works: [SubjectWork]
}

public struct SubjectWork: Codable, Sendable {
    public let key: String
    public let title: String
    public let coverId: Int?
    public let authors: [SubjectWorkAuthor]?

    enum CodingKeys: String, CodingKey {
        case key, title, authors
        case coverId = "cover_id"
    }

    public var asBookReference: BookReference {
        BookReference(
            workKey: key,
            title: title,
            authorName: authors?.first?.name,
            coverId: coverId
        )
    }
}

public struct SubjectWorkAuthor: Codable, Sendable {
    public let name: String
    public let key: String?
}

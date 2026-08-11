//
//  GoogleBooksSearchResponse.swift
//  Network
//
//  Created by Semih TAKILAN on 07.08.2026.
//

import Foundation
import Models

/// Google Books'un taşıma formatı; Domain `Book`'tan bağımsız tutulur.
struct GoogleBooksSearchResponse: Decodable, Sendable {
    let items: [GoogleBooksVolume]?

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([GoogleBooksVolume].self, forKey: .items)
    }

    private enum CodingKeys: String, CodingKey {
        case items
    }

    nonisolated func toBooks() -> [Book] {
        (items ?? []).map { $0.toDomain() }
    }
}

struct GoogleBooksVolume: Decodable, Sendable {
    let id: String
    let volumeInfo: GoogleBooksVolumeInfo

    nonisolated func toDomain() -> Book {
        Book(
            id: id,
            title: volumeInfo.title,
            authors: volumeInfo.authors ?? [],
            pageCount: volumeInfo.pageCount,
            coverURL: volumeInfo.coverURL,
            publishedDate: volumeInfo.publishedDate,
            description: volumeInfo.description,
            isbn13: volumeInfo.industryIdentifiers?
                .first(where: { $0.type == "ISBN_13" })?
                .identifier
        )
    }
}

struct GoogleBooksVolumeInfo: Decodable, Sendable {
    let title: String
    let authors: [String]?
    let pageCount: Int?
    let imageLinks: GoogleBooksImageLinks?
    let publishedDate: String?
    let description: String?
    let industryIdentifiers: [GoogleBooksIndustryIdentifier]?

    nonisolated var coverURL: URL? {
        let rawURL = imageLinks?.thumbnail ?? imageLinks?.smallThumbnail
        return rawURL
            .map { $0.replacingOccurrences(of: "http://", with: "https://") }
            .flatMap(URL.init(string:))
    }
}

struct GoogleBooksImageLinks: Decodable, Sendable {
    let thumbnail: String?
    let smallThumbnail: String?
}

struct GoogleBooksIndustryIdentifier: Decodable, Sendable {
    let type: String
    let identifier: String
}

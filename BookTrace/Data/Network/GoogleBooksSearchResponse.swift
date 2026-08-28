//
//  GoogleBooksSearchResponse.swift
//  Network
//
//  Created by Semih TAKILAN on 07.08.2026.
//

import Foundation
import Models

/// Google Books'un taşıma formatı; Domain `BookReference`'tan bağımsız tutulur.
struct GoogleBooksSearchResponse: Decodable, Sendable {
    let items: [GoogleBooksVolume]?

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([GoogleBooksVolume].self, forKey: .items)
    }

    private enum CodingKeys: String, CodingKey {
        case items
    }

    /// Başlıksız veya kimliği tekrar eden kayıtları eler; Google zaman zaman
    /// aynı cildi birden fazla baskıyla döndürüyor.
    nonisolated func toBookReferences() -> [BookReference] {
        var seenIDs = Set<String>()
        return (items ?? [])
            .filter { !$0.volumeInfo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { seenIDs.insert($0.id).inserted }
            .map { $0.toDomain() }
    }
}

struct GoogleBooksVolume: Decodable, Sendable {
    let id: String
    let volumeInfo: GoogleBooksVolumeInfo

    nonisolated func toDomain() -> BookReference {
        BookReference(
            id: id,
            title: volumeInfo.title,
            authors: volumeInfo.authors ?? [],
            coverURL: volumeInfo.coverURL,
            pageCount: volumeInfo.pageCount.flatMap { $0 > 0 ? $0 : nil },
            publishedDate: volumeInfo.publishedDate,
            description: volumeInfo.description,
            isbn13: volumeInfo.industryIdentifiers?
                .first(where: { $0.type == "ISBN_13" })?
                .identifier,
            subjects: volumeInfo.categories ?? []
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
    let categories: [String]?

    /// Google küçük kapakları hâlâ http üzerinden veriyor; ATS'i geçmesi için https'e çeviriyoruz.
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

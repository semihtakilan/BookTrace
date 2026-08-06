//
//  Book.swift
//  Models
//
//  Created by Semih TAKILAN on 31.07.2026.
//

import Foundation

/// Uygulama katmanlarının kullandığı, sağlayıcıdan bağımsız kitap entity'si.
public struct Book: Identifiable, Hashable, Sendable, Decodable {
    public let id: String
    public let title: String
    public let authors: [String]
    public let pageCount: Int?
    public let coverURL: URL?
    public let publishedDate: String?
    public let description: String?
    public let isbn13: String?

    public init(
        id: String,
        title: String,
        authors: [String] = [],
        pageCount: Int? = nil,
        coverURL: URL? = nil,
        publishedDate: String? = nil,
        description: String? = nil,
        isbn13: String? = nil
    ) {
        self.id = id
        self.title = title
        self.authors = authors
        self.pageCount = pageCount
        self.coverURL = coverURL
        self.publishedDate = publishedDate
        self.description = description
        self.isbn13 = isbn13
    }

    /// Google Books yanıtını doğrudan domain entity'sine decode eder.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)

        let volumeInfo = try container.nestedContainer(keyedBy: VolumeInfoKeys.self, forKey: .volumeInfo)
        title = try volumeInfo.decode(String.self, forKey: .title)
        authors = try volumeInfo.decodeIfPresent([String].self, forKey: .authors) ?? []
        pageCount = try volumeInfo.decodeIfPresent(Int.self, forKey: .pageCount)
        publishedDate = try volumeInfo.decodeIfPresent(String.self, forKey: .publishedDate)
        description = try volumeInfo.decodeIfPresent(String.self, forKey: .description)

        if let imageLinks = try? volumeInfo.nestedContainer(keyedBy: ImageLinkKeys.self, forKey: .imageLinks) {
            let rawURL = try imageLinks.decodeIfPresent(String.self, forKey: .thumbnail)
                ?? imageLinks.decodeIfPresent(String.self, forKey: .smallThumbnail)
            coverURL = rawURL
                .map { $0.replacingOccurrences(of: "http://", with: "https://") }
                .flatMap(URL.init(string:))
        } else {
            coverURL = nil
        }

        let identifiers = try volumeInfo.decodeIfPresent([IndustryIdentifier].self, forKey: .industryIdentifiers)
        isbn13 = identifiers?.first(where: { $0.type == "ISBN_13" })?.identifier
    }

    private enum CodingKeys: String, CodingKey {
        case id, volumeInfo
    }

    private enum VolumeInfoKeys: String, CodingKey {
        case title, authors, pageCount, imageLinks, publishedDate, description, industryIdentifiers
    }

    private enum ImageLinkKeys: String, CodingKey {
        case thumbnail, smallThumbnail
    }

    private struct IndustryIdentifier: Decodable {
        let type: String
        let identifier: String
    }
}

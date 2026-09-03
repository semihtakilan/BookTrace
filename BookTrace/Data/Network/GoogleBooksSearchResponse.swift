//
//  GoogleBooksSearchResponse.swift
//  Network
//
//  Created by Semih TAKILAN on 07.08.2026.
//

import Foundation
import Models

/// Google Books'un taşıma formatı; Domain `BookReference`'tan bağımsız tutulur.
///
/// Taşıma modelindeki her alan isteğe bağlı. Google zaman zaman başlıksız veya
/// eksik alanlı ciltler döndürüyor; alanlar zorunlu olsaydı tek bozuk kayıt
/// tüm sayfanın decode'unu düşürürdü. Eksik kayıtlar `toBookReferences()`
/// aşamasında sessizce eleniyor.
struct GoogleBooksSearchResponse: Decodable, Sendable {
    let items: [GoogleBooksVolume]?

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([GoogleBooksVolume].self, forKey: .items)
    }

    private enum CodingKeys: String, CodingKey {
        case items
    }

    /// Kimliği veya başlığı olmayan ve kimliği tekrar eden kayıtları eler.
    nonisolated func toBookReferences() -> [BookReference] {
        var seenIDs = Set<String>()
        return (items ?? [])
            .compactMap { $0.toDomain() }
            .filter { seenIDs.insert($0.id).inserted }
    }
}

nonisolated struct GoogleBooksVolume: Decodable, Sendable {
    let id: String?
    let volumeInfo: GoogleBooksVolumeInfo?

    /// Kullanılabilir bir kitap üretemiyorsa `nil` döner.
    func toDomain() -> BookReference? {
        guard let id, !id.isEmpty, let volumeInfo else { return nil }

        let title = volumeInfo.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else { return nil }

        return BookReference(
            // Kimlik kaynağıyla birlikte taşınıyor; iki katalogtan gelen
            // kayıtlar aynı dizede buluşamasın.
            id: BookIdentifier(source: .googleBooks, value: id).rawValue,
            title: title,
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
    let title: String?
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
    let type: String?
    let identifier: String?
}

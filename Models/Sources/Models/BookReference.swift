//
//  BookReference.swift
//  Models
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Foundation

/// Uzak kaynaktan (Google Books) gelen bir kitabın taşınabilir kimliği.
///
/// Explore'un üç farklı yolu — arama, kategori rafı, barkod — sonuçlarını bu tek
/// tipe indirger; Detay ekranı ve `LibraryEntry` yalnızca bunu tanır. Böylece
/// kitabın nereden geldiği akışın geri kalanını ilgilendirmez.
public struct BookReference: Identifiable, Hashable, Sendable, Codable {
    /// Google Books volume id — kütüphane kaydının da kimliği olur.
    public let id: String
    public let title: String
    public let authors: [String]
    public let coverURL: URL?
    public let pageCount: Int?
    public let publishedDate: String?
    public let description: String?
    public let isbn13: String?
    /// Kaynağın döndürdüğü konu etiketleri; öneri ve kategori önerisi için kullanılır.
    public let subjects: [String]

    public var author: String {
        authors.joined(separator: ", ")
    }

    /// Yayın tarihinin yılı; Google Books "2019", "2019-04" ve "2019-04-01" biçimlerini karışık döndürür.
    public var publicationYear: String? {
        guard let publishedDate, publishedDate.count >= 4 else { return nil }
        return String(publishedDate.prefix(4))
    }

    public init(
        id: String,
        title: String,
        authors: [String] = [],
        coverURL: URL? = nil,
        pageCount: Int? = nil,
        publishedDate: String? = nil,
        description: String? = nil,
        isbn13: String? = nil,
        subjects: [String] = []
    ) {
        self.id = id
        self.title = title
        self.authors = authors
        self.coverURL = coverURL
        self.pageCount = pageCount
        self.publishedDate = publishedDate
        self.description = description
        self.isbn13 = isbn13
        self.subjects = subjects
    }
}

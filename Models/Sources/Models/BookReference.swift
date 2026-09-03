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

    /// Gün bilgisi de varsa tarih. Ekranda ham ISO dizesi yerine yerelleştirilmiş
    /// biçimde gösterilebilsin diye.
    public var publicationDay: Date? {
        BookReference.date(from: publishedDate, componentCount: 3)
    }

    /// Yalnızca yıl ve ay verilmişse.
    public var publicationMonth: Date? {
        BookReference.date(from: publishedDate, componentCount: 2)
    }

    /// `DateFormatter` yerine elle ayrıştırılıyor: biçim sabit (ISO), formatter
    /// ise `Sendable` değil ve statik olarak paylaşılamıyor.
    private static func date(from value: String?, componentCount: Int) -> Date? {
        guard let value else { return nil }
        let parts = value.split(separator: "-").map(String.init)
        guard parts.count == componentCount else { return nil }

        let numbers = parts.compactMap { Int($0) }
        guard numbers.count == componentCount else { return nil }

        var components = DateComponents()
        components.year = numbers[0]
        components.month = componentCount > 1 ? numbers[1] : 1
        components.day = componentCount > 2 ? numbers[2] : 1

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        return calendar.date(from: components)
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

//
//  BookIdentifier.swift
//  Models
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation

/// Bir kitabın hangi kaynaktan geldiği.
public enum BookSource: String, Hashable, Sendable, Codable, CaseIterable {
    case googleBooks = "gb"
    case openLibrary = "ol"
}

/// Kaynak adıyla birlikte taşınan kitap kimliği.
///
/// Tek kaynak varken kimlik Google'ın volume id'siydi. İki kaynak olunca aynı
/// dizenin hangi kataloğa ait olduğu belirsizleşiyor — üstelik Open Library'nin
/// kimliği `/works/OL166894W` gibi eğik çizgi içeriyor. Kimliği önekleyerek
/// ayırıyoruz: `gb:zyTCAlFPjgYC`, `ol:/works/OL166894W`.
///
/// Öneki olmayan dizeler Google sayılıyor: kütüphanede kayıtlı eski kayıtlar
/// böyle yazılmıştı ve onları taşımak için ayrı bir migration'a gerek kalmıyor.
public struct BookIdentifier: Hashable, Sendable {
    public let source: BookSource
    public let value: String

    public init(source: BookSource, value: String) {
        self.source = source
        self.value = value
    }

    public init(rawValue: String) {
        let parts = rawValue.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 2, let source = BookSource(rawValue: String(parts[0])) {
            self.source = source
            value = String(parts[1])
        } else {
            source = .googleBooks
            value = rawValue
        }
    }

    public var rawValue: String {
        "\(source.rawValue):\(value)"
    }
}

public extension BookReference {
    var identifier: BookIdentifier {
        BookIdentifier(rawValue: id)
    }

    var source: BookSource {
        identifier.source
    }

    /// İki kaynağın aynı kitabı için ortak anahtar.
    ///
    /// ISBN varsa o kullanılıyor — tek gerçek kitap kimliği o. Yoksa başlık,
    /// ilk yazar ve yıldan bir imza üretiliyor; kusurlu ama iki katalog arasında
    /// elde kalan tek şey bu. Noktalama ve büyük/küçük harf atılıyor, çünkü
    /// kataloglar aynı kitabı "Dune." ve "dune" diye yazabiliyor.
    var matchingKey: String {
        if let isbn13, !isbn13.isEmpty { return "isbn:\(isbn13)" }

        let normalizedTitle = BookReference.normalizedForMatching(title)
        let normalizedAuthor = BookReference.normalizedForMatching(authors.first ?? "")
        return "title:\(normalizedTitle)|\(normalizedAuthor)|\(publicationYear ?? "")"
    }

    private static func normalizedForMatching(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

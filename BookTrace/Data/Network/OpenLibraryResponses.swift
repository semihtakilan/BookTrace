//
//  OpenLibraryResponses.swift
//  Network
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation
import Models

/// Open Library'nin taşıma formatı.
///
/// Google tarafında olduğu gibi burada da her alan isteğe bağlı: katalog
/// gönüllülerle büyüyor ve eksik alanlı kayıtlar olağan. Zorunlu bir alan tek
/// bozuk kayıtta bütün rafı düşürürdü.
nonisolated struct OpenLibrarySearchResponse: Decodable, Sendable {
    let docs: [OpenLibraryDocument]?

    func toBookReferences() -> [BookReference] {
        var seenIDs = Set<String>()
        return (docs ?? [])
            .compactMap { $0.toDomain() }
            .filter { seenIDs.insert($0.id).inserted }
    }
}

nonisolated struct OpenLibraryDocument: Decodable, Sendable {
    let key: String?
    let title: String?
    let authorName: [String]?
    /// `cover_i` — kapak kimliği.
    let coverI: Int?
    let firstPublishYear: Int?
    /// Eserin baskıları arasındaki medyan sayfa sayısı; belirli bir baskının
    /// değeri değil, ama bir tahmin için yeterli ve kullanıcı düzeltebiliyor.
    let numberOfPagesMedian: Int?

    func toDomain() -> BookReference? {
        guard let key, !key.isEmpty else { return nil }
        let title = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else { return nil }

        return BookReference(
            id: BookIdentifier(source: .openLibrary, value: key).rawValue,
            title: title,
            authors: authorName ?? [],
            coverURL: coverI.map(OpenLibraryHost.coverURL(id:)),
            pageCount: numberOfPagesMedian,
            publishedDate: firstPublishYear.map(String.init)
        )
    }
}

/// Eser kaydı: açıklama ve konular.
nonisolated struct OpenLibraryWork: Decodable, Sendable {
    let key: String?
    let title: String?
    let description: OpenLibraryText?
    let subjects: [String]?
    let covers: [Int]?

    func toDomain() -> BookReference? {
        guard let key, !key.isEmpty else { return nil }

        return BookReference(
            id: BookIdentifier(source: .openLibrary, value: key).rawValue,
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            coverURL: covers?.first(where: { $0 > 0 }).map(OpenLibraryHost.coverURL(id:)),
            description: description?.value.flatMap(OpenLibraryWork.plainText),
            subjects: OpenLibraryWork.presentableSubjects(subjects ?? [])
        )
    }

    /// Konular hem kırpılıyor hem eleniyor.
    ///
    /// Open Library bir esere yüzlerce konu bağlayabiliyor ve bunların bir kısmı
    /// kütüphane sınıflandırma artığı: "British and irish fiction (fictional
    /// works by one author)", "Large type books". Bu etiketler detayda yer
    /// kaplıyor, kategori önerisi olarak sunulduklarında ise kullanıcı onları
    /// kendi kütüphanesine ad olarak alıyor. Parantezli ve aşırı uzun olanlar
    /// düşüyor; geriye üçten azı kalırsa eleme yapılmıyor, çünkü bazı eserlerde
    /// zaten yalnızca bu tür etiketler var.
    static func presentableSubjects(_ subjects: [String]) -> [String] {
        let cleaned = subjects.filter { subject in
            !subject.contains("(") && subject.count <= 30
        }
        return Array((cleaned.count >= 3 ? cleaned : subjects).prefix(8))
    }

    /// Açıklamalar Markdown ile yazılıyor; ekranda düz metin gösteriyoruz.
    ///
    /// Sıra önemli: bağlantılar önce metinlerine indirgeniyor, vurgu işaretleri
    /// sonra siliniyor. Ters sırada `_` temizliği bağlantı adresinin içindeki
    /// alt çizgileri de yiyor ve ekranda
    /// "wikipedia.org/wiki/ThePictureofDorianGray" gibi bozuk bir adres kalıyor.
    static func plainText(_ value: String) -> String? {
        var text = value

        // [Wikipedia](https://...) ve [Wikipedia][1] → Wikipedia
        for pattern in ["\\[([^\\]]*)\\]\\([^)]*\\)", "\\[([^\\]]*)\\]\\[[^\\]]*\\]"] {
            text = text.replacingOccurrences(of: pattern, with: "$1", options: .regularExpression)
        }

        // Yatay çizgi satırları ("--------") ve tanımsız kalan dipnotlar.
        text = text.replacingOccurrences(of: "(?m)^\\s*[-*_]{3,}\\s*$", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?m)^\\s*\\[[^\\]]*\\]:.*$", with: "", options: .regularExpression)

        for marker in ["**", "__", "*", "_"] {
            text = text.replacingOccurrences(of: marker, with: "")
        }

        // Silinen satırların ardında kalan boşluklar tek boş satıra iniyor.
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Baskı kaydı: barkoddan gelen ISBN'in karşılığı.
nonisolated struct OpenLibraryEdition: Decodable, Sendable {
    let key: String?
    let title: String?
    let numberOfPages: Int?
    let publishDate: String?
    let covers: [Int]?
    let isbn13: [String]?
    let works: [OpenLibraryWorkReference]?

    /// Baskının eser anahtarı; açıklama için eser kaydına gitmek gerekiyor.
    var workKey: String? {
        works?.first?.key
    }

    /// Yazarlar burada yalnızca anahtar olarak duruyor (`/authors/OL22242A`);
    /// isimlerini almak kitap başına ayrı bir istek demek olurdu. Barkod
    /// akışında yazar adı arama sonucundan ya da eser kaydından geliyor.
    func toDomain(isbn: String) -> BookReference? {
        let title = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else { return nil }

        // Kimlik eser anahtarına bağlanıyor: aynı kitabın arama sonucundan
        // gelen hâliyle aynı satıra düşsün.
        let identifier = workKey ?? key ?? "isbn/\(isbn)"

        return BookReference(
            id: BookIdentifier(source: .openLibrary, value: identifier).rawValue,
            title: title,
            coverURL: covers?.first(where: { $0 > 0 }).map(OpenLibraryHost.coverURL(id:)),
            pageCount: numberOfPages,
            publishedDate: publishDate,
            isbn13: isbn13?.first ?? isbn
        )
    }
}

nonisolated struct OpenLibraryWorkReference: Decodable, Sendable {
    let key: String?
}

/// Open Library açıklamayı iki biçimde döndürüyor: düz dize, ya da
/// `{"type": "/type/text", "value": "..."}`. İkisini de karşılıyoruz.
nonisolated struct OpenLibraryText: Decodable, Sendable {
    let value: String?

    init(from decoder: Decoder) throws {
        if let text = try? decoder.singleValueContainer().decode(String.self) {
            value = text
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decodeIfPresent(String.self, forKey: .value)
    }

    private enum CodingKeys: String, CodingKey {
        case value
    }
}

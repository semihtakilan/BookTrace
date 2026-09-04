//
//  BookAmbience.swift
//  Models
//
//  Created by Semih TAKILAN on 04.09.2026.
//

import Foundation

/// Bir kitabın "havası" — okuma ekranının dokusunu, rengini ve hareketini belirler.
///
/// Kaynağın konu etiketleri serbest metin: Google Books "Fiction / Science
/// Fiction / Space Opera" derken Open Library "Science fiction, American"
/// diyebiliyor. Bu tip o dağınıklığı ekranın kullanabileceği sonlu bir kümeye
/// indirir. Sınıflandırma saf ve durumsuz olduğu için UI'a bağlanmadan test
/// edilebilir.
public enum BookAmbience: String, CaseIterable, Sendable, Hashable, Codable {
    /// Roman, öykü, genel kurgu — varsayılan.
    case literary
    case scienceFiction
    case mystery
    case history
    case philosophy
    case technology
    case biography
    case poetry
    case nature
    case children

    /// Konu etiketlerinden (gerekirse başlıktan) havayı çıkarır.
    public static func resolve(for book: BookReference) -> BookAmbience {
        resolve(subjects: book.subjects, title: book.title)
    }

    /// Kitap nesnesi olmadan da çağrılabilen biçim — keşif ekranındaki konu
    /// kartları da aynı eşlemeyi kullanıyor.
    public static func resolve(subjects: [String], title: String = "") -> BookAmbience {
        let subjectText = subjects.joined(separator: " · ").lowercased()
        if let match = match(in: subjectText) { return match }

        // Konu etiketi hiç yoksa ya da tanımadığımız bir şeyse başlığa bakılır.
        // Açıklama bilinçli olarak dışarıda: "a philosophy of running" gibi
        // cümleler kurgu kitaplarını yanlış rafa atıyordu.
        if let match = match(in: title.lowercased()) { return match }
        return .literary
    }

    /// Tek bir metinde geçen ilk eşleşme. Sıra önemlidir: "science fiction"
    /// hem `scienceFiction` hem `technology` anahtarlarıyla örtüşüyor, daha
    /// belirgin olan önce denenir.
    private static func match(in text: String) -> BookAmbience? {
        guard !text.isEmpty else { return nil }
        for (ambience, keywords) in orderedKeywords {
            if keywords.contains(where: text.contains) { return ambience }
        }
        return nil
    }

    /// Belirginden genele doğru sıralı anahtar kelimeler.
    ///
    /// `Dictionary` değil dizi: sözlüğün sırası tanımsız olduğu için aynı kitap
    /// iki açılışta iki farklı havaya düşebiliyordu.
    private static let orderedKeywords: [(BookAmbience, [String])] = [
        (.poetry, ["poetry", "poems", "poem", "verse", "şiir", "lyrik"]),
        (.children, ["juvenile", "children", "picture book", "young adult", "çocuk", "kinderbuch"]),
        (.scienceFiction, ["science fiction", "sciencefiction", "space opera", "dystopia", "cyberpunk",
                           "speculative", "bilim kurgu", "science-fiction"]),
        (.mystery, ["mystery", "detective", "thriller", "crime", "suspense", "noir", "horror",
                    "polisiye", "gerilim", "krimi"]),
        (.philosophy, ["philosophy", "ethics", "metaphysics", "stoic", "logic", "religion",
                       "spiritual", "felsefe", "philosophie"]),
        (.technology, ["computer", "computers", "programming", "software", "engineering",
                       "mathematics", "data", "artificial intelligence", "teknoloji", "bilgisayar",
                       "informatik"]),
        (.history, ["history", "historical", "war", "ancient", "medieval", "civilization",
                    "tarih", "geschichte"]),
        (.biography, ["biography", "autobiography", "memoir", "letters", "diaries", "personal narrative",
                      "biyografi", "anı", "biographie"]),
        (.nature, ["nature", "science", "biology", "astronomy", "environment", "travel", "ecology",
                   "doğa", "gezi", "natur"]),
        (.literary, ["fiction", "novel", "literary", "classics", "romance", "fantasy", "adventure",
                     "roman", "edebiyat", "öykü"])
    ]
}

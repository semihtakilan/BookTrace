//
//  BookQuery.swift
//  Models
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation

/// Uzak kaynağa sorulabilecek üç sorudan biri.
///
/// Cache anahtarı daha önce çağrı yerlerinde elle kurulan bir dizeydi
/// (`"subject:\(subject):\(maxResults)"`); anahtarı üreten yer ile onu okuyan
/// yer arasında hiçbir bağ yoktu. Sorguyu tipe çevirmek hem anahtarı hem de
/// tazelik penceresini tek yerde toplar: bir raf ile bir aramanın ne kadar
/// süreyle geçerli sayılacağı ikisinin ortak tanımından okunur.
public enum BookQuery: Hashable, Sendable {
    case search(text: String, maxResults: Int)
    case subject(String, maxResults: Int)
    case isbn(String)

    /// Cache satırının kimliği. Sorgu metni normalize edilir, yoksa "Dune" ve
    /// "dune " ayrı satırlar açar.
    public var cacheKey: String {
        switch self {
        case .search(let text, let maxResults):
            "search:\(BookQuery.normalized(text)):\(maxResults)"
        case .subject(let subject, let maxResults):
            "subject:\(BookQuery.normalized(subject)):\(maxResults)"
        case .isbn(let isbn):
            "isbn:\(isbn.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
    }

    /// Bu süreden sonra veri hâlâ gösterilir ama arka planda tazelenir.
    ///
    /// Kitap metadata'sı neredeyse hiç değişmediği için pencereler geniş: kota
    /// harcamamanın en ucuz yolu isteği hiç yapmamak.
    public var refreshInterval: TimeInterval {
        switch self {
        case .search:  .days(1)
        case .subject: .days(7)
        case .isbn:    .days(30)
        }
    }

    /// Bu süreden sonra veri gösterilmez; satır silinir ve sorgu yeniden sorulur.
    ///
    /// `refreshInterval`'dan uzun olması SWR'ın çalışma koşulu: arada kalan
    /// sürede kullanıcı beklemeden eski veriyi görür.
    public var timeToLive: TimeInterval {
        switch self {
        case .search:  .days(7)
        case .subject: .days(30)
        case .isbn:    .days(365)
        }
    }

    /// Bir sorgunun kaç sonuç istediği; cache'ten gelen listeyi kırpmak için.
    public var maxResults: Int {
        switch self {
        case .search(_, let maxResults):  maxResults
        case .subject(_, let maxResults): maxResults
        case .isbn:                       1
        }
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

public extension TimeInterval {
    static func days(_ count: Double) -> TimeInterval {
        count * 24 * 60 * 60
    }
}

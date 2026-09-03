//
//  OpenLibraryEndpoint.swift
//  Network
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation
import NetworkKit

nonisolated enum OpenLibraryHost {
    static let baseURL = URL(string: "https://openlibrary.org")!
    static let coversBaseURL = URL(string: "https://covers.openlibrary.org")!

    /// Open Library kendini tanıtan bir `User-Agent` istiyor: adressiz istekler
    /// saniyede bir, uygulama adı ve iletişim adresi verenler saniyede üçle
    /// sınırlanıyor. Adres gerçek olmalı — kurum bunu kötüye kullanımda
    /// yazışmak için istiyor.
    static var userAgent: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "BookTrace/\(version) (booktrace.help@gmail.com)"
    }

    /// Kapak adresi kapak kimliğinden kuruluyor, ISBN'den değil: ISBN ve OLID
    /// yolları IP başına beş dakikada 100 istekle sınırlı, kapak kimliği yolu
    /// bu sınırın dışında.
    static func coverURL(id: Int) -> URL {
        coversBaseURL.appending(path: "b/id/\(id)-M.jpg")
    }
}

/// Open Library arama ucu: hem serbest metin hem de konu rafı buradan çıkıyor.
struct OpenLibrarySearchEndpoint: Endpoint {
    typealias Response = OpenLibrarySearchResponse

    var path: String = "search.json"
    var queryParameters: [String: String]?
    var baseURL: URL { OpenLibraryHost.baseURL }
    var headers: [String: String] { ["User-Agent": OpenLibraryHost.userAgent] }

    /// Listede istenen alanlar.
    ///
    /// `isbn` ve `subject` bilerek yok. Ölçüldüğünde 15 sonuçluk bir yanıt bu
    /// alanlarla 2.6 KB, `isbn` eklendiğinde 191 KB'ye çıkıyor — Open Library
    /// eserin *bütün* baskılarının ISBN'lerini döndürüyor. İkisi de yalnızca
    /// detay ekranında gerekiyor, orada tek kitap için isteniyor.
    private static let listFields = [
        "key", "title", "author_name", "cover_i", "first_publish_year", "number_of_pages_median"
    ].joined(separator: ",")

    private init(query: String, limit: Int) {
        queryParameters = [
            "q": query,
            "fields": Self.listFields,
            "limit": String(max(limit, 1))
        ]
    }

    /// Rafın istediğinden fazlasını getirir.
    ///
    /// Open Library'de kapağı olmayan eser çok; raf da göze hitap eden bir yer,
    /// kapaksız kartlar sırayı boşaltıyor. Fazladan gelen sonuçlar kapaklıları
    /// öne almaya yetiyor ve bu ek bir istek değil — aynı isteğin daha uzun
    /// listesi.
    static let coverOversamplingFactor = 2

    static func search(query: String, maxResults: Int) -> Self {
        Self(query: query, limit: maxResults)
    }

    static func subject(_ subject: String, maxResults: Int) -> Self {
        Self(query: "subject:\(subject)", limit: maxResults)
    }

    /// ISBN ile *eser* araması. Baskıya özel doğru başlık için
    /// `OpenLibraryEditionEndpoint` kullanılıyor; bu yalnızca yedek.
    static func isbn(_ isbn: String) -> Self {
        Self(query: "isbn:\(isbn)", limit: 1)
    }
}

/// Eserin kendi kaydı: açıklama ve konular yalnızca burada.
struct OpenLibraryWorkEndpoint: Endpoint {
    typealias Response = OpenLibraryWork

    var path: String
    var queryParameters: [String: String]?
    var baseURL: URL { OpenLibraryHost.baseURL }
    var headers: [String: String] { ["User-Agent": OpenLibraryHost.userAgent] }

    /// - Parameter workKey: `/works/OL166894W` biçiminde, arama sonucundaki `key`.
    init(workKey: String) {
        path = workKey.hasPrefix("/") ? String(workKey.dropFirst()) + ".json" : workKey + ".json"
    }
}

/// ISBN'den baskı kaydı.
///
/// Arama ucu eser düzeyinde cevap veriyor ve eserin başlığı özgün dilinde
/// olabiliyor: İngilizce Penguin baskısının ISBN'i arandığında
/// "Преступление и наказание" dönüyor. Barkodu okutan kullanıcı elindeki
/// baskıyı görmek istiyor, bu yüzden barkod yolu baskı kaydından geçiyor.
/// `/isbn/...` bir yönlendirme döndürür; `URLSession` onu kendisi izler.
struct OpenLibraryEditionEndpoint: Endpoint {
    typealias Response = OpenLibraryEdition

    var path: String
    var queryParameters: [String: String]?
    var baseURL: URL { OpenLibraryHost.baseURL }
    var headers: [String: String] { ["User-Agent": OpenLibraryHost.userAgent] }

    init(isbn: String) {
        path = "isbn/\(isbn).json"
    }
}

//
//  GoogleBooksEndpoint.swift
//  Network
//
//  Created by Semih TAKILAN on 06.08.2026.
//

import Foundation
import NetworkKit

/// İsteğe eklenen ülke kodu.
///
/// Google Books, `country` parametresi olmadan gelen çağrılara `503
/// backendFailed` döndürüyor — ve verilen değeri çağıranın IP'sinden tespit
/// ettiği ülkeyle karşılaştırıyor, uyuşmazsa yine 503. Bu yüzden sabit bir
/// değer yerine cihazın bölge ayarını gönderiyoruz.
nonisolated enum GoogleBooksRegion {
    static var current: String {
        Locale.current.region?.identifier ?? "US"
    }
}

/// `Endpoint.baseURL` aktör dışı bir bağlamdan okunuyor; sabit de aktör dışı
/// olmak zorunda. Dosya kapsamındaki bir `let`, varsayılan aktör yalıtımı
/// `MainActor` olduğu için oraya bağlanırdı.
nonisolated enum GoogleBooksHost {
    static let baseURL = URL(string: "https://www.googleapis.com/books/v1")!
}

/// Google Books `volumes` uç noktası.
///
/// Explore'un üç girişi de aynı uç noktaya farklı `q` ifadeleriyle çıkar; bu
/// yüzden tek bir endpoint tipi ve üç fabrika metodu yeterli.
struct GoogleBooksSearchEndpoint: Endpoint {
    typealias Response = GoogleBooksSearchResponse

    var path: String = "volumes"
    var queryParameters: [String: String]?
    var baseURL: URL { GoogleBooksHost.baseURL }

    /// Google, anahtara konan "iOS uygulamaları" kısıtlamasını bu başlıkla
    /// doğruluyor. Başlık gönderilmezse kısıtlanmış bir anahtar 403 döner —
    /// yani kısıtlamayı açmadan önce bunun yerinde olması gerekiyor.
    var headers: [String: String] { Self.restrictionHeaders }

    static var restrictionHeaders: [String: String] {
        var headers = ["Content-Type": "application/json"]
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            headers["X-Ios-Bundle-Identifier"] = bundleIdentifier
        }
        return headers
    }

    private init(query: String, maxResults: Int, apiKey: String?) {
        var parameters = [
            "q": query,
            "maxResults": String(min(max(maxResults, 1), 40)),
            "printType": "books",
            "country": GoogleBooksRegion.current
        ]
        // Anahtar yoksa istek yine gider; Google anahtarsız çağrıları düşük kotayla karşılar.
        if let apiKey {
            parameters["key"] = apiKey
        }
        queryParameters = parameters
    }

    /// Serbest metin arama.
    static func search(query: String, maxResults: Int, apiKey: String?) -> Self {
        Self(query: query, maxResults: maxResults, apiKey: apiKey)
    }

    /// Konu rafı — Google Books `subject:` önekini bekler.
    static func subject(_ subject: String, maxResults: Int, apiKey: String?) -> Self {
        Self(query: "subject:\"\(subject)\"", maxResults: maxResults, apiKey: apiKey)
    }

    /// Barkoddan gelen ISBN ile tek kitap sorgusu.
    static func isbn(_ isbn: String, apiKey: String?) -> Self {
        Self(query: "isbn:\(isbn)", maxResults: 1, apiKey: apiKey)
    }
}

/// Tek cildin kaydı.
///
/// Arama ucu bir listeyi, bu tek kitabı döndürüyor. Detay zenginleştirmesi
/// buradan geçiyor: kullanıcının gerçekten açtığı kitap için bir istek, arama
/// sonucundaki yirmi kitap için sıfır.
struct GoogleBooksVolumeEndpoint: Endpoint {
    typealias Response = GoogleBooksVolume

    var path: String
    var queryParameters: [String: String]?
    var baseURL: URL { GoogleBooksHost.baseURL }
    var headers: [String: String] { GoogleBooksSearchEndpoint.restrictionHeaders }

    init(volumeID: String, apiKey: String?) {
        path = "volumes/\(volumeID)"
        var parameters = ["country": GoogleBooksRegion.current]
        if let apiKey {
            parameters["key"] = apiKey
        }
        queryParameters = parameters
    }
}

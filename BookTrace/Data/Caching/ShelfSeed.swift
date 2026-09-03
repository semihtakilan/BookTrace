//
//  ShelfSeed.swift
//  Caching
//
//  Created by Semih TAKILAN on 04.09.2026.
//

import Foundation
import Models

/// Cache boşken bir sorguya cevap verebilen kaynak.
///
/// Mağaza bunu okuyor; böylece tohumlama okuma yolunda, aktörün içinde ve
/// yarışsız gerçekleşiyor. Ayrı bir "açılışta tohumla" görevi, Explore'un ondan
/// önce sorması hâlinde boş ekran gösterirdi.
nonisolated protocol BookSeedProviding: Sendable {
    func books(for query: BookQuery) -> [BookReference]?
}

/// Uygulamayla birlikte gelen raf anlık görüntüsü.
///
/// Explore'un altı rafı her kullanıcıda aynı ve içerikleri neredeyse hiç
/// değişmiyor. Yine de ilk açılışta altı istek gidiyordu ve Open Library'nin
/// konu sorgusu yavaş (ölçülen 2-4 saniye). Anlık görüntü uygulamanın içinde:
/// ilk açılış anında doluyor, ağa çıkmıyor, uçak modunda bile çalışıyor.
///
/// `Scripts/generate_shelf_seed.py` ile üretiliyor.
nonisolated struct ShelfSeed: BookSeedProviding {
    private let shelves: [String: [BookReference]]

    private struct Payload: Decodable {
        struct Shelf: Decodable {
            let subject: String
            let maxResults: Int
            let books: [BookReference]
        }
        let shelves: [Shelf]
    }

    /// Dosya okunamazsa boş kalıyor: tohum bir hızlandırma, uygulamanın
    /// çalışma koşulu değil. Raflar o zaman ağdan gelir.
    init(bundle: Bundle = .main, resource: String = "ShelfSeed") {
        guard let url = bundle.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            shelves = [:]
            return
        }

        shelves = Dictionary(
            payload.shelves.map { (BookQuery.subject($0.subject, maxResults: $0.maxResults).cacheKey, $0.books) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func books(for query: BookQuery) -> [BookReference]? {
        guard case .subject = query else { return nil }
        return shelves[query.cacheKey]
    }
}

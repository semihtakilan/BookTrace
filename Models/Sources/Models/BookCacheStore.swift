//
//  BookCacheStore.swift
//  Models
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation

/// Cache'ten dönen sonuç ve tazeliği.
///
/// `isStale` çağıranın kararını değiştirir: veri gösterilir ama arka planda
/// yenilenir. Bunu ayrı bir bayrak yerine "cache boş" sayarak çözmek, ağ yavaş
/// ya da kapalıyken kullanıcıyı elinde olan veriden mahrum bırakırdı.
public struct CachedBooks: Equatable, Sendable {
    public let books: [BookReference]
    public let isStale: Bool

    public init(books: [BookReference], isStale: Bool) {
        self.books = books
        self.isStale = isStale
    }
}

/// Kitap cache'inin sözleşmesi.
///
/// İki ayrı erişim var, çünkü iki ayrı ihtiyaç var: listeler sorguyla
/// (`books(for:)`), detay ekranı tek kitapla (`book(id:)`) konuşur. Aynı kitap
/// birden çok sorguda geçtiğinde tek satır olarak saklanır ve detay verisi
/// geldikçe üstüne yazılır; böylece bir rafta görülen kitap, açıldığında
/// yeniden indirilmez.
public protocol BookCacheStore: Sendable {
    func books(for query: BookQuery) async -> CachedBooks?
    func store(_ books: [BookReference], for query: BookQuery) async

    /// Tek kitabın bilinen en zengin hâli.
    func book(id: String) async -> BookReference?

    /// Kitabı cache'e işler; alan alan birleştirir, dolu alanı boşla ezmez.
    func merge(_ book: BookReference) async

    /// Saklanan her şeyi siler.
    func removeAll() async
}

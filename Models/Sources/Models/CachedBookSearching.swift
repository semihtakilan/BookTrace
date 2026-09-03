//
//  CachedBookSearching.swift
//  Models
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation

/// Cache'i önce okuyan, süresi geçmiş veriyi de gösterip arka planda tazeleyen
/// dekoratör.
///
/// Eskisi (`CacheFirstBookSearching`) yalnızca iki hâl biliyordu: cache'te var,
/// ya da yok. Süre dolduğu anda kullanıcı yeniden spinner görüyordu ve kotadan
/// bir istek daha gidiyordu — üstelik dönen veri neredeyse her zaman aynıydı,
/// çünkü bir kitabın başlığı ya da sayfa sayısı değişmiyor. Burada üç hâl var:
///
/// * taze     → cache'ten döner, ağa çıkılmaz
/// * bayat    → cache'ten **hemen** döner, tazeleme arka plana atılır
/// * yok      → uzak kaynağa gidilir
///
/// Bayat veriyi göstermek bilinçli bir tercih: yanlış olma ihtimali olan bilgi,
/// kullanıcıyı bekletmekten ve kota harcamaktan daha ucuz.
public struct CachedBookSearching: BookSearching, BookDetailFetching, Sendable {
    private let remote: any BookSearching & BookDetailFetching
    private let store: any BookCacheStore

    public init(remote: any BookSearching & BookDetailFetching, store: any BookCacheStore) {
        self.remote = remote
        self.store = store
    }

    public func searchBooks(query: String, maxResults: Int) async throws -> [BookReference] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await books(for: .search(text: text, maxResults: maxResults)) {
            try await remote.searchBooks(query: text, maxResults: maxResults)
        }
    }

    public func books(inSubject subject: String, maxResults: Int) async throws -> [BookReference] {
        let subject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await books(for: .subject(subject, maxResults: maxResults)) {
            try await remote.books(inSubject: subject, maxResults: maxResults)
        }
    }

    public func findBook(isbn: String) async throws -> BookReference {
        let isbn = isbn.trimmingCharacters(in: .whitespacesAndNewlines)
        let books = try await books(for: .isbn(isbn)) {
            [try await remote.findBook(isbn: isbn)]
        }
        guard let book = books.first else {
            throw CachedBookSearchingError.bookNotFound
        }
        return book
    }

    /// Detay da cache'ten geçiyor.
    ///
    /// Kullanıcı bir kitabı açıp geri dönüp tekrar açtığında ikinci kez istek
    /// gitmemeli; üstelik aynı kitap rafta da duruyor, zenginleşen kayıt oraya
    /// da yansıyor. Ölçüt açıklamanın varlığı: detay isteğinin asıl sebebi o.
    public func detail(for book: BookReference) async throws -> BookReference {
        let known = await store.book(id: book.id).map { book.merging($0) } ?? book
        if let description = known.description, !description.isEmpty {
            return known
        }

        let detail = try await remote.detail(for: known)
        await store.merge(detail)
        return detail
    }

    private func books(
        for query: BookQuery,
        fetch: @escaping @Sendable () async throws -> [BookReference]
    ) async throws -> [BookReference] {
        if let cached = await store.books(for: query) {
            if cached.isStale {
                refreshInBackground(query, fetch: fetch)
            }
            return cached.books
        }

        let books = try await fetch()
        await store.store(books, for: query)
        return books
    }

    /// Tazeleme kullanıcının isteğine bağlı değil: ekran çoktan doldu, bu iş
    /// başarısız olursa da elde bayat veri kalır. Bu yüzden hata yutuluyor ve
    /// çağıran görevin iptali tazelemeyi öldürmesin diye `Task.detached`.
    private func refreshInBackground(
        _ query: BookQuery,
        fetch: @escaping @Sendable () async throws -> [BookReference]
    ) {
        let store = store
        Task.detached(priority: .background) {
            guard let books = try? await fetch(), !books.isEmpty else { return }
            await store.store(books, for: query)
        }
    }
}

public enum CachedBookSearchingError: LocalizedError {
    case bookNotFound

    public var errorDescription: String? {
        "The requested book could not be found."
    }
}

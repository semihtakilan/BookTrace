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
    private let details: BookDetailRequestCache

    public init(remote: any BookSearching & BookDetailFetching, store: any BookCacheStore) {
        self.init(remote: remote, store: store, missingDetailRetryInterval: 30, now: Date.init)
    }

    init(
        remote: any BookSearching & BookDetailFetching,
        store: any BookCacheStore,
        missingDetailRetryInterval: TimeInterval,
        now: @escaping @Sendable () -> Date
    ) {
        self.remote = remote
        self.store = store
        self.details = BookDetailRequestCache(
            remote: remote,
            store: store,
            retryInterval: missingDetailRetryInterval,
            now: now
        )
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
        try await details.detail(for: book)
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

/// Aynı kitabı bekleyen ekranlar tek isteği paylaşır. Bir ekran kapanınca
/// yalnızca kendi bekleyişi iptal olur; son ekran da kapanırsa ağ işi durur.
private actor BookDetailRequestCache {
    private struct Waiter {
        let book: BookReference
        let continuation: CheckedContinuation<BookReference, any Error>
    }

    private struct Request {
        let id: UUID
        let task: Task<Void, Never>
        var waiters: [UUID: Waiter]
    }

    private let remote: any BookDetailFetching
    private let store: any BookCacheStore
    private let retryInterval: TimeInterval
    private let now: @Sendable () -> Date
    private var requests: [String: Request] = [:]
    private var missingDetails: [String: Date] = [:]
    private let maximumMissingDetails = 128

    init(
        remote: any BookDetailFetching,
        store: any BookCacheStore,
        retryInterval: TimeInterval,
        now: @escaping @Sendable () -> Date
    ) {
        self.remote = remote
        self.store = store
        self.retryInterval = max(0, retryInterval)
        self.now = now
    }

    func detail(for book: BookReference) async throws -> BookReference {
        try Task.checkCancellation()
        let known = await store.book(id: book.id).map { book.merging($0) } ?? book
        try Task.checkCancellation()
        if Self.hasDescription(known) {
            missingDetails.removeValue(forKey: book.id)
            return known
        }

        let date = now()
        missingDetails = missingDetails.filter { $0.value > date }
        if missingDetails[book.id] != nil {
            return known
        }

        let waiterID = UUID()
        let result = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let waiter = Waiter(book: known, continuation: continuation)
                if requests[book.id] != nil {
                    requests[book.id]?.waiters[waiterID] = waiter
                    return
                }

                let requestID = UUID()
                let task = Task {
                    do {
                        let fetched = try await remote.detail(for: known)
                        try Task.checkCancellation()
                        await finish(book.id, requestID: requestID, result: .success(known.merging(fetched)))
                    } catch {
                        await finish(book.id, requestID: requestID, result: .failure(error))
                    }
                }
                requests[book.id] = Request(id: requestID, task: task, waiters: [waiterID: waiter])
            }
        } onCancel: {
            Task { await self.cancel(book.id, waiterID: waiterID) }
        }
        try Task.checkCancellation()
        return result
    }

    private func finish(
        _ bookID: String,
        requestID: UUID,
        result: Result<BookReference, any Error>
    ) async {
        guard requests[bookID]?.id == requestID else { return }
        if case let .success(detail) = result {
            await store.merge(detail)
            guard requests[bookID]?.id == requestID else { return }
            if !Self.hasDescription(detail), retryInterval > 0 {
                if missingDetails.count >= maximumMissingDetails,
                   let oldest = missingDetails.min(by: { $0.value < $1.value })?.key {
                    missingDetails.removeValue(forKey: oldest)
                }
                missingDetails[bookID] = now().addingTimeInterval(retryInterval)
            }
        }
        guard let request = requests.removeValue(forKey: bookID) else { return }
        for waiter in request.waiters.values {
            waiter.continuation.resume(with: result.map { waiter.book.merging($0) })
        }
    }

    private func cancel(_ bookID: String, waiterID: UUID) {
        guard let waiter = requests[bookID]?.waiters.removeValue(forKey: waiterID) else { return }
        waiter.continuation.resume(throwing: CancellationError())
        if requests[bookID]?.waiters.isEmpty == true {
            requests.removeValue(forKey: bookID)?.task.cancel()
        }
    }

    private static func hasDescription(_ book: BookReference) -> Bool {
        !(book.description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
}

public enum CachedBookSearchingError: LocalizedError {
    case bookNotFound

    public var errorDescription: String? {
        "The requested book could not be found."
    }
}

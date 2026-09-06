//
//  HybridBookSearching.swift
//  Models
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation

/// Pahalı kaynağa gitmeden önce sorulan izin.
///
/// "Pahalı" burada para değil kota demek: Google Books'un günlük tavanı
/// uygulamanın *bütün* kullanıcıları arasında paylaşılıyor, yani tek bir cihazın
/// aşırı kullanımı herkesin aramasını durdurabilir.
public protocol RequestBudget: Sendable {
    /// Bir istek hakkı ister. `false` dönerse istek hiç yapılmamalı.
    func consume() async -> Bool

    /// Uzak kaynak kota hatası verdi; kalan süre boyunca ona gidilmemeli.
    func recordQuotaFailure() async
}

/// İki kaynağı birleştiren yönlendirme politikası.
///
/// Kural: **genişlik ucuz kaynaktan, derinlik pahalı kaynaktan.** Listeler çok
/// istek üretip az veri istiyor, tek kitap az istek üretip çok veri istiyor.
/// Open Library'nin günlük tavanı yok ama liste kayıtları fakir; Google Books
/// zengin ama günlük tavanı bütün kullanıcılarca paylaşılıyor. Bu yüzden:
///
/// * arama ve raflar → Open Library; yalnızca sonuç boş dönerse Google
/// * barkod → Open Library baskı kaydı; bulunamazsa Google
/// * detay → Open Library; kısa sürede açıklama gelmezse kota dahilinde Google
///
/// Yedeğe düşerken kullanıcı hiçbir şey fark etmiyor: iki kaynak da aynı
/// `BookReference`'ı üretiyor.
public struct HybridBookSearching: BookSearching, BookDetailFetching, Sendable {
    private let primary: any BookSearching
    private let fallback: any BookSearching & BookDetailFetching
    private let primaryDetail: any BookDetailFetching
    private let budget: any RequestBudget
    private let detailFallbackDelay: Duration
    private let detailTimeout: Duration

    public init(
        primary: any BookSearching,
        primaryDetail: any BookDetailFetching,
        fallback: any BookSearching & BookDetailFetching,
        budget: any RequestBudget,
        detailFallbackDelay: Duration = .milliseconds(800),
        detailTimeout: Duration = .seconds(8)
    ) {
        self.primary = primary
        self.primaryDetail = primaryDetail
        self.fallback = fallback
        self.budget = budget
        self.detailFallbackDelay = max(.zero, detailFallbackDelay)
        self.detailTimeout = max(.milliseconds(1), detailTimeout)
    }

    public func searchBooks(query: String, maxResults: Int) async throws -> [BookReference] {
        try await withFallback {
            try await primary.searchBooks(query: query, maxResults: maxResults)
        } fallback: {
            try await fallback.searchBooks(query: query, maxResults: maxResults)
        }
    }

    public func books(inSubject subject: String, maxResults: Int) async throws -> [BookReference] {
        try await withFallback {
            try await primary.books(inSubject: subject, maxResults: maxResults)
        } fallback: {
            try await fallback.books(inSubject: subject, maxResults: maxResults)
        }
    }

    public func findBook(isbn: String) async throws -> BookReference {
        let books = try await withFallback {
            [try await primary.findBook(isbn: isbn)]
        } fallback: {
            [try await fallback.findBook(isbn: isbn)]
        }

        guard let book = books.first else { throw HybridBookSearchingError.bookNotFound }
        return book
    }

    /// Hızlı bir Open Library yanıtı kota harcamaz. Yavaş yanıtta Google da
    /// devreye girer; ilk açıklama ekranı doldurur ve diğer istek iptal edilir.
    /// Açıklamasız/başarısız bir yanıt yarışı kazanmaz: diğer kaynak beklenir.
    /// Süre sınırı raf kuyruğunu ve bütün ağ denemelerini birlikte kapsar.
    public func detail(for book: BookReference) async throws -> BookReference {
        try Task.checkCancellation()
        guard !Self.hasDescription(book) else { return book }

        return try await withThrowingTaskGroup(of: DetailEvent.self) { group in
            defer { group.cancelAll() }
            var enriched = book
            var primaryFinished = book.source != .openLibrary
            var fallbackStarted = false
            var fallbackFinished = false
            var receivedMetadata = false
            var firstError: Error?

            group.addTask {
                try await Task.sleep(for: detailTimeout)
                return .deadline
            }

            if !primaryFinished {
                group.addTask {
                    do { return .primary(.success(try await primaryDetail.detail(for: book))) }
                    catch {
                        if Self.isCancellation(error) || Task.isCancelled { throw CancellationError() }
                        return .primary(.failure(error))
                    }
                }
                group.addTask {
                    try await Task.sleep(for: detailFallbackDelay)
                    return .startFallback
                }
            } else {
                fallbackStarted = true
                group.addTask { try await fallbackDetail(for: book) }
            }

            while let event = try await group.next() {
                try Task.checkCancellation()
                switch event {
                case .primary(let result), .fallback(let result):
                    if case .primary = event { primaryFinished = true }
                    else { fallbackFinished = true }
                    switch result {
                    case .success(let detail):
                        enriched = enriched.merging(detail)
                        receivedMetadata = true
                        if Self.hasDescription(enriched) { return enriched }
                    case .failure(let error):
                        firstError = firstError ?? error
                    }
                case .fallbackUnavailable:
                    fallbackFinished = true
                case .startFallback:
                    break
                case .deadline:
                    throw firstError ?? URLError(.timedOut)
                }

                // Açıklamasız birincil yanıt geldiğinde bekleme penceresinin
                // dolmasına gerek yok. Gecikme sinyali de aynı yolu kullanır.
                if !fallbackStarted {
                    fallbackStarted = true
                    let input = enriched
                    group.addTask { try await fallbackDetail(for: input) }
                }

                if primaryFinished && fallbackFinished {
                    if !receivedMetadata, let firstError { throw firstError }
                    return enriched
                }
            }
            return enriched
        }
    }

    private func fallbackDetail(for book: BookReference) async throws -> DetailEvent {
        try Task.checkCancellation()
        guard await budget.consume() else { return .fallbackUnavailable }
        try Task.checkCancellation()
        do {
            return .fallback(.success(try await fallback.detail(for: book)))
        } catch {
            if Self.isCancellation(error) || Task.isCancelled { throw CancellationError() }
            if Self.isQuotaFailure(error) { await budget.recordQuotaFailure() }
            return .fallback(.failure(error))
        }
    }

    private static func hasDescription(_ book: BookReference) -> Bool {
        !(book.description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    private enum DetailEvent: Sendable {
        case primary(Result<BookReference, Error>)
        case fallback(Result<BookReference, Error>)
        case fallbackUnavailable
        case startFallback
        case deadline
    }

    /// Birincil kaynağı dener; boş ya da hatalı dönerse — ve bütçe elverirse —
    /// yedeğe geçer.
    ///
    /// İptal edilen iş yedeğe düşmüyor: kullanıcı ekrandan çıktığında ya da
    /// yazmaya devam ettiğinde önceki istek iptal olur, onu ikinci kaynağa
    /// taşımak boşuna kota harcamak olurdu.
    private func withFallback(
        _ operation: () async throws -> [BookReference],
        fallback fallbackOperation: () async throws -> [BookReference]
    ) async throws -> [BookReference] {
        var primaryError: Error?

        do {
            let books = try await operation()
            if !books.isEmpty { return books }
        } catch {
            if HybridBookSearching.isCancellation(error) { throw error }
            primaryError = error
        }

        guard await budget.consume() else {
            if let primaryError { throw primaryError }
            return []
        }

        do {
            return try await fallbackOperation()
        } catch {
            if HybridBookSearching.isQuotaFailure(error) {
                await budget.recordQuotaFailure()
            }
            // Birincil kaynağın hatası kullanıcıya daha yakın: aramanın asıl
            // yolu oydu, yedek yalnızca bir kurtarma denemesiydi.
            throw primaryError ?? error
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    private static func isQuotaFailure(_ error: Error) -> Bool {
        (error as? QuotaFailureReporting)?.isQuotaFailure ?? false
    }
}

/// Kota hatasını devre kesiciye bildirebilen hatalar.
///
/// Uzak kaynağın hata tipleri Models'ta tanımlı değil (ağ katmanı uygulamada);
/// bu küçük sözleşme, politikanın onları tanımadan da doğru davranmasını
/// sağlıyor.
public protocol QuotaFailureReporting {
    var isQuotaFailure: Bool { get }
}

public enum HybridBookSearchingError: LocalizedError {
    case bookNotFound

    public var errorDescription: String? {
        "The requested book could not be found."
    }
}

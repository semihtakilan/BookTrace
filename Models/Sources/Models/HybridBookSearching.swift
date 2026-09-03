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
/// * detay → kitabın kendi kaynağı; açıklama hâlâ yoksa Google
///
/// Yedeğe düşerken kullanıcı hiçbir şey fark etmiyor: iki kaynak da aynı
/// `BookReference`'ı üretiyor.
public struct HybridBookSearching: BookSearching, BookDetailFetching, Sendable {
    private let primary: any BookSearching
    private let fallback: any BookSearching & BookDetailFetching
    private let primaryDetail: any BookDetailFetching
    private let budget: any RequestBudget

    public init(
        primary: any BookSearching,
        primaryDetail: any BookDetailFetching,
        fallback: any BookSearching & BookDetailFetching,
        budget: any RequestBudget
    ) {
        self.primary = primary
        self.primaryDetail = primaryDetail
        self.fallback = fallback
        self.budget = budget
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

    /// Kitabı, kendi kaynağından derinleştirir; açıklama hâlâ yoksa diğerine sorar.
    ///
    /// Açıklama tek başına ikinci bir isteği hak eden alan: detay ekranının
    /// gövdesi o. Sayfa sayısı ya da kapak eksikse kullanıcı bunu kendi
    /// girebiliyor, ama açıklamanın yerini hiçbir şey doldurmuyor.
    public func detail(for book: BookReference) async throws -> BookReference {
        let enriched = (try? await primaryDetailIfPossible(book)) ?? book

        guard enriched.description?.isEmpty ?? true else { return enriched }
        guard await budget.consume() else { return enriched }

        do {
            return try await fallback.detail(for: enriched)
        } catch {
            if HybridBookSearching.isQuotaFailure(error) {
                await budget.recordQuotaFailure()
            }
            return enriched
        }
    }

    private func primaryDetailIfPossible(_ book: BookReference) async throws -> BookReference {
        guard book.source == .openLibrary else { return book }
        return try await primaryDetail.detail(for: book)
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

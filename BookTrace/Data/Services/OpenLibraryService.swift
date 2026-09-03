//
//  OpenLibraryService.swift
//  Services
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation
import Models
import NetworkKit

/// Open Library'nin uygulama içindeki tek erişim noktası.
///
/// Anahtar istemiyor ve günlük tavanı yok; sınırı istek *hızı* (IP başına
/// saniyede üç). Kotanın darboğaz olduğu yerlerde — listeler — birincil kaynak
/// bu. Karşılığında liste kayıtları fakir: açıklama yok, sayfa sayısı baskılar
/// arası medyan, konular ayrı bir istekte.
final class OpenLibraryService: BookSearching, BookDetailFetching {
    private let networkService: any NetworkServiceProtocol
    private let throttle: RequestThrottle

    /// Saniyede üç istek: kendini tanıtan istemciler için açıklanan sınır.
    init(networkService: any NetworkServiceProtocol,
         throttle: RequestThrottle = RequestThrottle(minimumInterval: .milliseconds(340))) {
        self.networkService = networkService
        self.throttle = throttle
    }

    func searchBooks(query: String, maxResults: Int) async throws -> [BookReference] {
        try await execute {
            try await networkService
                .execute(OpenLibrarySearchEndpoint.search(query: query, maxResults: maxResults))
                .toBookReferences()
        }
    }

    func books(inSubject subject: String, maxResults: Int) async throws -> [BookReference] {
        try await execute {
            try await networkService
                .execute(OpenLibrarySearchEndpoint.subject(subject, maxResults: maxResults))
                .toBookReferences()
        }
    }

    /// Barkod yolu: önce baskı kaydı, olmazsa eser araması.
    ///
    /// Baskı kaydı doğru başlığı veriyor ama yazarı yalnızca anahtar olarak
    /// taşıyor; arama sonucu ise yazar adını veriyor. Yazar boş kalırsa —
    /// kullanıcının detay ekranında ilk baktığı şeylerden biri — aramadan
    /// tamamlanıyor. Bu ikinci istek yalnızca gerektiğinde gidiyor.
    func findBook(isbn: String) async throws -> BookReference {
        let edition = try? await execute {
            try await networkService.execute(OpenLibraryEditionEndpoint(isbn: isbn)).toDomain(isbn: isbn)
        }

        guard let edition else {
            return try await findBookBySearching(isbn: isbn)
        }

        guard edition.authors.isEmpty else { return edition }

        guard let searched = try? await findBookBySearching(isbn: isbn) else { return edition }
        return edition.merging(BookReference(id: edition.id, title: "", authors: searched.authors))
    }

    func detail(for book: BookReference) async throws -> BookReference {
        guard book.source == .openLibrary else {
            throw OpenLibraryServiceError.unsupportedSource
        }

        let detail = try await execute {
            try await networkService
                .execute(OpenLibraryWorkEndpoint(workKey: book.identifier.value))
                .toDomain()
        }

        guard let detail else { throw OpenLibraryServiceError.bookNotFound }
        return book.merging(detail)
    }

    private func findBookBySearching(isbn: String) async throws -> BookReference {
        let books = try await execute {
            try await networkService
                .execute(OpenLibrarySearchEndpoint.isbn(isbn))
                .toBookReferences()
        }

        guard let book = books.first else { throw OpenLibraryServiceError.bookNotFound }
        // Arama eser düzeyinde cevap veriyor ve ISBN'i taşımıyor; barkodu
        // okutan kullanıcı için o numara kaydın parçası.
        return book.merging(BookReference(id: book.id, title: "", isbn13: isbn))
    }

    /// Her isteği sıraya sokar ve ağ hatalarını uygulamanın tanıdığı hatalara
    /// çevirir.
    private func execute<Value>(_ work: () async throws -> Value) async throws -> Value {
        await throttle.wait()

        do {
            return try await work()
        } catch let error as NetworkError {
            switch error.statusCode {
            case 404:      throw OpenLibraryServiceError.bookNotFound
            case 403, 429: throw OpenLibraryServiceError.rateLimited
            default:       throw error
            }
        }
    }
}

enum OpenLibraryServiceError: LocalizedError, Equatable {
    case bookNotFound
    case rateLimited
    case unsupportedSource

    var errorDescription: String? {
        switch self {
        case .bookNotFound:
            "This book could not be found on Open Library."
        case .rateLimited:
            "Open Library is busy right now."
        case .unsupportedSource:
            "This book did not come from Open Library."
        }
    }
}

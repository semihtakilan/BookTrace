//
//  GoogleBooksService.swift
//  Services
//
//  Created by Semih TAKILAN on 06.08.2026.
//

import Foundation
import Models
import NetworkKit

/// Google Books API'nin uygulama içindeki tek erişim noktası.
final class GoogleBooksService: BookSearching, BookDetailFetching {
    private let networkService: any NetworkServiceProtocol

    init(networkService: any NetworkServiceProtocol) {
        self.networkService = networkService
    }

    func searchBooks(query: String, maxResults: Int) async throws -> [BookReference] {
        try await execute {
            GoogleBooksSearchEndpoint.search(query: query, maxResults: maxResults, apiKey: $0)
        }
    }

    func books(inSubject subject: String, maxResults: Int) async throws -> [BookReference] {
        try await execute {
            GoogleBooksSearchEndpoint.subject(subject, maxResults: maxResults, apiKey: $0)
        }
    }

    func findBook(isbn: String) async throws -> BookReference {
        let books = try await execute { GoogleBooksSearchEndpoint.isbn(isbn, apiKey: $0) }
        guard let book = books.first else {
            throw GoogleBooksServiceError.bookNotFound
        }
        return book
    }

    /// Kitabın eksik alanlarını Google'dan tamamlar.
    ///
    /// Üç yol var ve hepsi tek istek: kitap Google'dan geldiyse cilt kaydı,
    /// ISBN'i varsa ISBN sorgusu, ikisi de yoksa başlık ve yazarla arama.
    /// Sonuncusu yanlış kitabı getirebileceği için başlık karşılaştırılıyor —
    /// kullanıcıya başka bir kitabın açıklamasını göstermektense açıklamasız
    /// bırakmak yeğdir.
    func detail(for book: BookReference) async throws -> BookReference {
        let identifier = book.identifier

        if identifier.source == .googleBooks {
            let volume = try await executeVolume(identifier.value)
            guard let detail = volume.toDomain() else { throw GoogleBooksServiceError.bookNotFound }
            return book.merging(detail)
        }

        let candidates: [BookReference]
        if let isbn13 = book.isbn13, !isbn13.isEmpty {
            candidates = try await searchBooks(query: "isbn:\(isbn13)", maxResults: 1)
        } else {
            let author = book.authors.first.map { " \($0)" } ?? ""
            candidates = try await searchBooks(query: "\(book.title)\(author)", maxResults: 3)
        }

        guard let match = candidates.first(where: { $0.matchingKey == book.matchingKey })
                ?? candidates.first(where: { GoogleBooksService.titlesMatch($0.title, book.title) }) else {
            throw GoogleBooksServiceError.bookNotFound
        }
        return book.merging(match)
    }

    private static func titlesMatch(_ first: String, _ second: String) -> Bool {
        let normalize = { (value: String) in
            value.folding(options: [.diacriticInsensitive, .caseInsensitive],
                          locale: Locale(identifier: "en_US_POSIX"))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return normalize(first) == normalize(second)
    }

    private func executeVolume(_ volumeID: String) async throws -> GoogleBooksVolume {
        let apiKey = GoogleBooksAPIKey.value
        do {
            return try await networkService.execute(GoogleBooksVolumeEndpoint(volumeID: volumeID, apiKey: apiKey))
        } catch let error as NetworkError {
            throw GoogleBooksService.mapped(error, hasAPIKey: apiKey != nil)
        }
    }

    /// Anahtarı tek yerden geçirir ve kota hatalarını kullanıcıya anlamlı gelen
    /// bir mesaja çevirir; ham "HTTP 429" kimseye ne yapacağını söylemiyor.
    private func execute(
        _ makeEndpoint: (String?) -> GoogleBooksSearchEndpoint
    ) async throws -> [BookReference] {
        let apiKey = GoogleBooksAPIKey.value

        do {
            return try await networkService.execute(makeEndpoint(apiKey)).toBookReferences()
        } catch let error as NetworkError {
            throw GoogleBooksService.mapped(error, hasAPIKey: apiKey != nil)
        }
    }

    private static func mapped(_ error: NetworkError, hasAPIKey: Bool) -> Error {
        switch error.statusCode {
        case 429, 403:
            GoogleBooksServiceError.quotaExceeded(hasAPIKey: hasAPIKey)
        case 404:
            GoogleBooksServiceError.bookNotFound
        case 503:
            GoogleBooksServiceError.regionUnavailable(GoogleBooksRegion.current)
        case nil where error.isDecodingFailure:
            // NetworkKit'in decode hatası tüm gövdeyi metne gömüyor; onu
            // kullanıcıya göstermek yerine loglarda bırakıyoruz.
            GoogleBooksServiceError.unreadableResponse
        default:
            error
        }
    }
}

private extension NetworkError {
    var isDecodingFailure: Bool {
        if case .decodingError = self { return true }
        return false
    }
}

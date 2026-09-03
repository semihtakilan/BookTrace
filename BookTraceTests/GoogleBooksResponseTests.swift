//
//  GoogleBooksResponseTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation
import Testing
@testable import BookTrace

/// Taşıma modelinin bozuk veriye dayanıklılığı: Google Books başlıksız veya
/// eksik alanlı ciltler döndürüyor ve tek bozuk kayıt tüm sayfayı düşürmemeli.
struct GoogleBooksResponseTests {

    private func decode(_ json: String) throws -> GoogleBooksSearchResponse {
        try JSONDecoder().decode(GoogleBooksSearchResponse.self, from: Data(json.utf8))
    }

    @Test func aResponseWithoutItemsDecodesToAnEmptyList() throws {
        #expect(try decode(#"{"totalItems": 0}"#).toBookReferences().isEmpty)
        #expect(try decode(#"{"items": null}"#).toBookReferences().isEmpty)
    }

    @Test func unusableVolumesAreDroppedButTheRestSurvive() throws {
        let response = try decode(#"""
        {"items": [
          {"id": "ok-1", "volumeInfo": {"title": "Dune", "authors": ["Frank Herbert"]}},
          {"volumeInfo": {"title": "No identifier"}},
          {"id": "no-title", "volumeInfo": {"authors": ["Nobody"]}},
          {"id": "blank-title", "volumeInfo": {"title": "   "}},
          {"id": "no-volume-info"},
          {"id": "ok-2", "volumeInfo": {"title": "Neuromancer"}}
        ]}
        """#)

        let books = response.toBookReferences()

        #expect(books.map(\.id) == ["ok-1", "ok-2"])
        #expect(books[0].author == "Frank Herbert")
        #expect(books[1].author.isEmpty)
    }

    @Test func repeatedIdentifiersAreKeptOnlyOnce() throws {
        let response = try decode(#"""
        {"items": [
          {"id": "same", "volumeInfo": {"title": "First"}},
          {"id": "same", "volumeInfo": {"title": "Duplicate"}},
          {"id": "other", "volumeInfo": {"title": "Second"}}
        ]}
        """#)

        let books = response.toBookReferences()

        #expect(books.map(\.id) == ["same", "other"])
        #expect(books[0].title == "First")
    }

    @Test func coverURLsAreUpgradedToHTTPS() throws {
        let response = try decode(#"""
        {"items": [{"id": "a", "volumeInfo": {
          "title": "Dune",
          "imageLinks": {"smallThumbnail": "http://books.google.com/small.jpg"}
        }}]}
        """#)

        #expect(response.toBookReferences().first?.coverURL?.scheme == "https")
    }

    @Test func aThumbnailWinsOverASmallThumbnail() throws {
        let response = try decode(#"""
        {"items": [{"id": "a", "volumeInfo": {
          "title": "Dune",
          "imageLinks": {
            "smallThumbnail": "https://books.google.com/small.jpg",
            "thumbnail": "https://books.google.com/large.jpg"
          }
        }}]}
        """#)

        #expect(response.toBookReferences().first?.coverURL?.lastPathComponent == "large.jpg")
    }

    @Test func aZeroPageCountIsTreatedAsUnknown() throws {
        let response = try decode(#"""
        {"items": [{"id": "a", "volumeInfo": {"title": "Dune", "pageCount": 0}}]}
        """#)

        #expect(response.toBookReferences().first?.pageCount == nil)
    }

    @Test func onlyTheISBN13IsPickedUp() throws {
        let response = try decode(#"""
        {"items": [{"id": "a", "volumeInfo": {
          "title": "Dune",
          "industryIdentifiers": [
            {"type": "ISBN_10", "identifier": "0441013597"},
            {"type": "ISBN_13", "identifier": "9780441013593"}
          ]
        }}]}
        """#)

        #expect(response.toBookReferences().first?.isbn13 == "9780441013593")
    }
}

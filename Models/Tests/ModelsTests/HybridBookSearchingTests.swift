//
//  HybridBookSearchingTests.swift
//  ModelsTests
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation
import Testing
@testable import Models

/// Bütçeyi test kontrol ediyor: kaç istek geçirdiğini ve kota hatası duyup
/// duymadığını sayıyor.
private actor BudgetMock: RequestBudget {
    private var allowance: Int
    private(set) var consumeCallCount = 0
    private(set) var quotaFailureCount = 0

    init(allowance: Int = .max) {
        self.allowance = allowance
    }

    func consume() async -> Bool {
        consumeCallCount += 1
        guard allowance > 0 else { return false }
        allowance -= 1
        return true
    }

    func recordQuotaFailure() async {
        quotaFailureCount += 1
    }
}

private struct FailingSearch: BookSearching, BookDetailFetching {
    let error: Error

    func searchBooks(query: String, maxResults: Int) async throws -> [BookReference] { throw error }
    func books(inSubject subject: String, maxResults: Int) async throws -> [BookReference] { throw error }
    func findBook(isbn: String) async throws -> BookReference { throw error }
    func detail(for book: BookReference) async throws -> BookReference { throw error }
}

private struct EmptySearch: BookSearching {
    func searchBooks(query: String, maxResults: Int) async throws -> [BookReference] { [] }
    func books(inSubject subject: String, maxResults: Int) async throws -> [BookReference] { [] }
    func findBook(isbn: String) async throws -> BookReference { throw TestError.notFound }
}

private struct StubDetail: BookDetailFetching {
    let result: BookReference

    func detail(for book: BookReference) async throws -> BookReference { book.merging(result) }
}

private struct FailingDetail: BookDetailFetching {
    func detail(for book: BookReference) async throws -> BookReference { throw TestError.notFound }
}

private struct QuotaError: Error, QuotaFailureReporting {
    var isQuotaFailure: Bool { true }
}

private enum TestError: Error {
    case notFound
    case offline
}

/// Yedek kaynak: hem arama hem detay verebiliyor.
private struct StubSource: BookSearching, BookDetailFetching {
    let books: [BookReference]
    let detailResult: BookReference?

    init(books: [BookReference], detailResult: BookReference? = nil) {
        self.books = books
        self.detailResult = detailResult
    }

    func searchBooks(query: String, maxResults: Int) async throws -> [BookReference] { books }
    func books(inSubject subject: String, maxResults: Int) async throws -> [BookReference] { books }
    func findBook(isbn: String) async throws -> BookReference {
        guard let first = books.first else { throw TestError.notFound }
        return first
    }
    func detail(for book: BookReference) async throws -> BookReference {
        guard let detailResult else { throw TestError.notFound }
        return book.merging(detailResult)
    }
}

@Suite struct HybridBookSearchingTests {

    private func makeReference(_ id: String, description: String? = nil) -> BookReference {
        BookReference(id: id, title: "Dune", authors: ["Herbert"], description: description)
    }

    @Test func theCheapSourceAnswersAndTheQuotaIsNeverTouched() async throws {
        let budget = BudgetMock()
        let searching = HybridBookSearching(
            primary: StubSource(books: [makeReference("ol:/works/1")]),
            primaryDetail: FailingDetail(),
            fallback: StubSource(books: [makeReference("gb:1")]),
            budget: budget
        )

        let books = try await searching.searchBooks(query: "dune", maxResults: 20)

        #expect(books.map(\.id) == ["ol:/works/1"])
        #expect(await budget.consumeCallCount == 0)
    }

    @Test func anEmptyResultFallsBackToTheRicherSource() async throws {
        let budget = BudgetMock()
        let searching = HybridBookSearching(
            primary: EmptySearch(),
            primaryDetail: FailingDetail(),
            fallback: StubSource(books: [makeReference("gb:1")]),
            budget: budget
        )

        let books = try await searching.searchBooks(query: "dune", maxResults: 20)

        #expect(books.map(\.id) == ["gb:1"])
        #expect(await budget.consumeCallCount == 1)
    }

    @Test func aFailingPrimarySourceFallsBack() async throws {
        let searching = HybridBookSearching(
            primary: FailingSearch(error: TestError.offline),
            primaryDetail: FailingDetail(),
            fallback: StubSource(books: [makeReference("gb:1")]),
            budget: BudgetMock()
        )

        let books = try await searching.books(inSubject: "history", maxResults: 15)
        #expect(books.map(\.id) == ["gb:1"])
    }

    /// Bütçe bittiğinde yedek kaynağa hiç gidilmiyor; kullanıcı boş liste görür,
    /// paylaşılan kota korunur.
    @Test func anExhaustedBudgetStopsTheFallbackAltogether() async throws {
        let budget = BudgetMock(allowance: 0)
        let searching = HybridBookSearching(
            primary: EmptySearch(),
            primaryDetail: FailingDetail(),
            fallback: StubSource(books: [makeReference("gb:1")]),
            budget: budget
        )

        let books = try await searching.searchBooks(query: "dune", maxResults: 20)

        #expect(books.isEmpty)
        #expect(await budget.consumeCallCount == 1)
    }

    /// İptal kullanıcıdan geliyor (ekrandan çıktı, yazmaya devam etti); ikinci
    /// kaynağa gitmek boşuna kota harcamak olurdu.
    @Test func aCancelledRequestIsNotRetriedOnTheOtherSource() async throws {
        let budget = BudgetMock()
        let searching = HybridBookSearching(
            primary: FailingSearch(error: CancellationError()),
            primaryDetail: FailingDetail(),
            fallback: StubSource(books: [makeReference("gb:1")]),
            budget: budget
        )

        await #expect(throws: CancellationError.self) {
            try await searching.searchBooks(query: "dune", maxResults: 20)
        }
        #expect(await budget.consumeCallCount == 0)
    }

    @Test func aQuotaFailureIsReportedSoTheSourceCanBeSuspended() async throws {
        let budget = BudgetMock()
        let searching = HybridBookSearching(
            primary: EmptySearch(),
            primaryDetail: FailingDetail(),
            fallback: FailingSearch(error: QuotaError()),
            budget: budget
        )

        _ = try? await searching.searchBooks(query: "dune", maxResults: 20)

        #expect(await budget.quotaFailureCount == 1)
    }

    /// Her iki kaynak da düşerse kullanıcıya birincil kaynağın hatası
    /// gösterilir: aramanın asıl yolu oydu.
    @Test func thePrimaryFailureIsTheOneReported() async throws {
        let searching = HybridBookSearching(
            primary: FailingSearch(error: TestError.offline),
            primaryDetail: FailingDetail(),
            fallback: FailingSearch(error: TestError.notFound),
            budget: BudgetMock()
        )

        await #expect(throws: TestError.offline) {
            try await searching.searchBooks(query: "dune", maxResults: 20)
        }
    }

    @Test func aDescriptionFromTheCheapSourceMakesTheSecondRequestUnnecessary() async throws {
        let budget = BudgetMock()
        let searching = HybridBookSearching(
            primary: EmptySearch(),
            primaryDetail: StubDetail(result: makeReference("ol:/works/1", description: "A desert planet.")),
            fallback: StubSource(books: [], detailResult: makeReference("gb:1", description: "Longer text.")),
            budget: budget
        )

        let book = try await searching.detail(for: makeReference("ol:/works/1"))

        #expect(book.description == "A desert planet.")
        #expect(await budget.consumeCallCount == 0)
    }

    @Test func aMissingDescriptionIsWorthOneRequestToTheRicherSource() async throws {
        let budget = BudgetMock()
        let searching = HybridBookSearching(
            primary: EmptySearch(),
            primaryDetail: StubDetail(result: makeReference("ol:/works/1")),
            fallback: StubSource(books: [], detailResult: makeReference("gb:1", description: "From Google.")),
            budget: budget
        )

        let book = try await searching.detail(for: makeReference("ol:/works/1"))

        #expect(book.description == "From Google.")
        // Kimlik korunuyor: kullanıcı kitabı kütüphanesine eklediyse aynı kayıt.
        #expect(book.id == "ol:/works/1")
        #expect(await budget.consumeCallCount == 1)
    }

    /// Zenginleştirme başarısız olsa da ekran dolmalı: elde olan kayıt döner.
    @Test func aFailedEnrichmentStillReturnsTheBookInHand() async throws {
        let searching = HybridBookSearching(
            primary: EmptySearch(),
            primaryDetail: FailingDetail(),
            fallback: FailingSearch(error: TestError.notFound),
            budget: BudgetMock()
        )

        let book = try await searching.detail(for: makeReference("ol:/works/1"))
        #expect(book.id == "ol:/works/1")
        #expect(book.description == nil)
    }
}

@Suite struct BookIdentifierTests {

    @Test func anIdentifierRoundTripsThroughItsRawValue() {
        let identifier = BookIdentifier(source: .openLibrary, value: "/works/OL166894W")
        #expect(identifier.rawValue == "ol:/works/OL166894W")
        #expect(BookIdentifier(rawValue: identifier.rawValue) == identifier)
    }

    /// Önek eklenmeden önce kaydedilmiş kimlikler Google'a ait.
    @Test func anUnprefixedIdentifierIsReadAsGoogleBooks() {
        let identifier = BookIdentifier(rawValue: "zyTCAlFPjgYC")
        #expect(identifier.source == .googleBooks)
        #expect(identifier.value == "zyTCAlFPjgYC")
    }

    @Test func anUnknownPrefixIsPartOfTheIdentifierRatherThanASource() {
        let identifier = BookIdentifier(rawValue: "urn:isbn:123")
        #expect(identifier.source == .googleBooks)
        #expect(identifier.value == "urn:isbn:123")
    }

    @Test func twoCataloguesAgreeOnABookThroughItsISBN() {
        let fromGoogle = BookReference(id: "gb:1", title: "Dune", isbn13: "9780441013593")
        let fromOpenLibrary = BookReference(id: "ol:/works/1", title: "Dune.", isbn13: "9780441013593")

        #expect(fromGoogle.matchingKey == fromOpenLibrary.matchingKey)
    }

    /// ISBN yoksa başlık ve yazardan bir imza kalıyor; noktalama ve aksan
    /// kataloglar arasında değişebiliyor.
    @Test func withoutAnISBNTheTitleAndAuthorCarryTheMatch() {
        let first = BookReference(id: "gb:1", title: "Kürk Mantolu Madonna",
                                  authors: ["Sabahattin Ali"], publishedDate: "1943")
        let second = BookReference(id: "ol:/works/1", title: "Kurk mantolu madonna!",
                                   authors: ["sabahattin ali"], publishedDate: "1943-01-01")

        #expect(first.matchingKey == second.matchingKey)
    }

    @Test func differentBooksDoNotShareAMatchingKey() {
        let dune = BookReference(id: "gb:1", title: "Dune", authors: ["Herbert"])
        let neuromancer = BookReference(id: "gb:2", title: "Neuromancer", authors: ["Gibson"])

        #expect(dune.matchingKey != neuromancer.matchingKey)
    }
}

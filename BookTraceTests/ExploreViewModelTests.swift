//
//  ExploreViewModelTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 06.09.2026.
//

import Foundation
import Models
import Testing
@testable import BookTrace

@MainActor
struct ExploreViewModelTests {
    @Test func discoveryCollectionsFollowShelfLoadsRetriesAndFailures() async {
        let catalog = ControlledSearchCatalog()
        let viewModel = ExploreViewModel(bookSearching: catalog)
        let first = viewModel.shelves[0]
        let second = viewModel.shelves[1]
        let shared = makeBook(id: "shared", pageCount: 200)
        let short = makeBook(id: "short", pageCount: 100)
        let long = makeBook(id: "long", pageCount: 600)

        let firstLoad = Task { await viewModel.retry(shelf: first) }
        await catalog.waitForRequest(first.subject.query)
        #expect(viewModel.spotlights.isEmpty)
        await catalog.succeed(first.subject.query, books: [long, shared, shared])
        await firstLoad.value
        #expect(viewModel.spotlights.map(\.book.id) == ["shared"])
        #expect(viewModel.discoverableBooks.map(\.id) == ["long", "shared"])

        let secondLoad = Task { await viewModel.retry(shelf: second) }
        await catalog.waitForRequest(second.subject.query)
        await catalog.succeed(second.subject.query, books: [shared, short])
        await secondLoad.value
        #expect(viewModel.shortReads.map(\.id) == ["short", "shared"])
        #expect(viewModel.discoverableBooks.map(\.id) == ["long", "shared", "short"])

        let retry = Task { await viewModel.retry(shelf: second) }
        await catalog.waitForRequest(second.subject.query)
        #expect(viewModel.shortReads.map(\.id) == ["shared"])
        await catalog.fail(second.subject.query)
        await retry.value
        #expect(viewModel.spotlights.count == 1)
        #expect(viewModel.shortReads.map(\.id) == ["shared"])
    }

    @Test func anOlderResponseCannotReplaceTheCurrentSearch() async {
        let catalog = ControlledSearchCatalog()
        let viewModel = ExploreViewModel(bookSearching: catalog)
        viewModel.searchText = "Dune"
        let oldSearch = Task { await viewModel.performSearch() }
        await catalog.waitForRequest("Dune")

        viewModel.searchText = "Earthsea"
        let newSearch = Task { await viewModel.performSearch() }
        await catalog.waitForRequest("Earthsea")
        await catalog.succeed("Earthsea", books: [makeBook(id: "new", title: "Earthsea")])
        await newSearch.value
        await catalog.succeed("Dune", books: [makeBook(id: "old")])
        await oldSearch.value

        #expect(viewModel.searchState.value?.map(\.id) == ["new"])
    }

    @Test func aLateFailureCannotEraseNewResults() async {
        let catalog = ControlledSearchCatalog()
        let viewModel = ExploreViewModel(bookSearching: catalog)
        viewModel.searchText = "old"
        let oldSearch = Task { await viewModel.performSearch() }
        await catalog.waitForRequest("old")

        viewModel.searchText = "new"
        let newSearch = Task { await viewModel.performSearch() }
        await catalog.waitForRequest("new")
        await catalog.succeed("new", books: [makeBook(id: "new")])
        await newSearch.value
        await catalog.fail("old")
        await oldSearch.value

        #expect(viewModel.searchState.value?.map(\.id) == ["new"])
        #expect(viewModel.searchState.error == nil)
    }

    @Test func clearingSearchInvalidatesAnInFlightRequest() async {
        let catalog = ControlledSearchCatalog()
        let viewModel = ExploreViewModel(bookSearching: catalog)
        viewModel.searchText = "Dune"
        let search = Task { await viewModel.performSearch() }
        await catalog.waitForRequest("Dune")
        viewModel.clearSearch()
        await catalog.succeed("Dune", books: [makeBook()])
        await search.value

        #expect(viewModel.searchState.isIdle)
        #expect(!viewModel.isShowingSearchResults)
    }

    @Test func aCancelledProviderResponseDoesNotPublishResults() async {
        let catalog = ControlledSearchCatalog()
        let viewModel = ExploreViewModel(bookSearching: catalog)
        viewModel.searchText = "Dune"
        let search = Task { await viewModel.performSearch() }
        await catalog.waitForRequest("Dune")
        search.cancel()
        await catalog.succeed("Dune", books: [makeBook()])
        await search.value

        #expect(viewModel.searchState.isIdle)
    }

    @Test func changingTheQueryImmediatelyHidesItsPreviousResults() async {
        let catalog = ControlledSearchCatalog()
        let viewModel = ExploreViewModel(bookSearching: catalog)
        viewModel.searchText = "Dune"
        let search = Task { await viewModel.performSearch() }
        await catalog.waitForRequest("Dune")
        await catalog.succeed("Dune", books: [makeBook(), makeBook(), makeBook(id: "second")])
        await search.value
        #expect(viewModel.searchState.value?.map(\.id) == ["book-1", "second"])

        viewModel.searchText = "Earthsea"
        #expect(viewModel.searchState.isIdle)
    }
}

/// Deliberately ignores task cancellation, as a cache or callback-based SDK can.
/// Tests decide response order without sleeps or timing assumptions.
private actor ControlledSearchCatalog: BookSearching {
    private var requests: [String: CheckedContinuation<[BookReference], any Error>] = [:]
    private var observers: [String: CheckedContinuation<Void, Never>] = [:]

    func searchBooks(query: String, maxResults: Int) async throws -> [BookReference] {
        try await withCheckedThrowingContinuation { continuation in
            requests[query] = continuation
            observers.removeValue(forKey: query)?.resume()
        }
    }

    func waitForRequest(_ query: String) async {
        guard requests[query] == nil else { return }
        await withCheckedContinuation { observers[query] = $0 }
    }

    func succeed(_ query: String, books: [BookReference]) {
        requests.removeValue(forKey: query)?.resume(returning: books)
    }

    func fail(_ query: String) {
        requests.removeValue(forKey: query)?.resume(throwing: URLError(.notConnectedToInternet))
    }

    func books(inSubject subject: String, maxResults: Int) async throws -> [BookReference] {
        try await searchBooks(query: subject, maxResults: maxResults)
    }
    func findBook(isbn: String) async throws -> BookReference { BookReference(id: isbn, title: "Scanned book") }
}

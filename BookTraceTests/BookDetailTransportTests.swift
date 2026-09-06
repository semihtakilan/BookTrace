//
//  BookDetailTransportTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 06.09.2026.
//

import Foundation
import Models
import NetworkKit
import Testing
@testable import BookTrace

@MainActor
struct BookDetailTransportTests {
    @Test func detailRequestsHaveAShortTimeoutAndNoTransportRetries() throws {
        let work = OpenLibraryWorkEndpoint(workKey: "/works/OL1W")
        let volume = GoogleBooksVolumeEndpoint(volumeID: "volume-1", apiKey: nil)
        let search = GoogleBooksSearchEndpoint.detail(query: "Dune", maxResults: 3, apiKey: nil)

        #expect(try work.urlRequest().timeoutInterval == 6)
        #expect(try volume.urlRequest().timeoutInterval == 6)
        #expect(try search.urlRequest().timeoutInterval == 6)
        #expect(work.maximumAttempts == 1)
        #expect(volume.maximumAttempts == 1)
        #expect(search.maximumAttempts == 1)
        #expect(search.queryParameters?["q"] == "Dune")
        #expect(search.queryParameters?["maxResults"] == "3")
    }

    @Test func listRequestsRetainTheirExistingRetryPolicy() throws {
        let openLibrary = OpenLibrarySearchEndpoint.search(query: "Dune", maxResults: 15)
        let google = GoogleBooksSearchEndpoint.search(query: "Dune", maxResults: 15, apiKey: nil)

        #expect(try openLibrary.urlRequest().timeoutInterval == 30)
        #expect(try google.urlRequest().timeoutInterval == 30)
        #expect(openLibrary.maximumAttempts == nil)
        #expect(google.maximumAttempts == nil)
    }

    @Test func aCancelledThrottledRequestDoesNotReachTheNetwork() async throws {
        let throttle = RequestThrottle(minimumInterval: .seconds(60))
        try await throttle.wait()
        let network = CancelledDetailNetwork()
        let service = OpenLibraryService(networkService: network, throttle: throttle)
        let request = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await service.detail(for: makeBook(id: "ol:/works/OL1W"))
        }

        do {
            _ = try await request.value
            Issue.record("Expected cancellation")
        } catch {
            #expect(error is CancellationError)
        }
        #expect(await network.calls == 0)
    }

    @Test func providersExposeTransportCancellationToTheHybridLoader() async {
        let network = CancelledDetailNetwork()
        let openLibrary = OpenLibraryService(networkService: network)
        let google = GoogleBooksService(networkService: network)

        do {
            _ = try await openLibrary.detail(for: makeBook(id: "ol:/works/OL1W"))
            Issue.record("Expected Open Library cancellation")
        } catch {
            #expect(error is CancellationError)
        }
        do {
            _ = try await google.detail(for: makeBook(id: "gb:volume-1"))
            Issue.record("Expected Google Books cancellation")
        } catch {
            #expect(error is CancellationError)
        }
    }

    @Test func foreignCatalogDescriptionsUseTheDetailRequestPolicy() async throws {
        let network = DetailSearchNetwork()
        let service = GoogleBooksService(networkService: network)
        let book = makeBook(id: "ol:/works/OL1W")

        let detail = try await service.detail(for: book)

        #expect(detail.id == book.id)
        #expect(detail.description == "A desert planet.")
        #expect(await network.query == "Dune Frank Herbert")
        #expect(await network.maximumAttempts == 1)
        #expect(await network.timeout == 6)
    }

    @Test func isbnDetailLookupUsesTheSameBoundedRequestPolicy() async throws {
        let network = DetailSearchNetwork()
        let service = GoogleBooksService(networkService: network)
        let book = BookReference(
            id: "ol:/works/OL1W", title: "Dune", authors: ["Frank Herbert"], isbn13: "9780441013593"
        )

        _ = try await service.detail(for: book)

        #expect(await network.query == "isbn:9780441013593")
        #expect(await network.maximumAttempts == 1)
        #expect(await network.timeout == 6)
    }
}

private actor CancelledDetailNetwork: NetworkServiceProtocol {
    private(set) var calls = 0

    func execute<T: Endpoint>(_ endpoint: T) async throws -> T.Response {
        calls += 1
        throw NetworkError.cancelled
    }
}

private actor DetailSearchNetwork: NetworkServiceProtocol {
    private(set) var query: String?
    private(set) var maximumAttempts: Int?
    private(set) var timeout: TimeInterval?

    func execute<T: Endpoint>(_ endpoint: T) async throws -> T.Response {
        query = endpoint.queryParameters?["q"]
        maximumAttempts = endpoint.maximumAttempts
        timeout = endpoint.timeout
        return try JSONDecoder().decode(T.Response.self, from: Data(#"""
        {"items":[{"id":"dune","volumeInfo":{
          "title":"Dune","authors":["Frank Herbert"],"description":"A desert planet."
        }}]}
        """#.utf8))
    }
}

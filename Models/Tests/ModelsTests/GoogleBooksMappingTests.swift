import Foundation
import Testing
@testable import Models

struct GoogleBooksMappingTests {

    @Test func searchUseCaseTrimsTheQueryAndUsesItsRepository() async throws {
        let repository = BookSearchingMock()
        let useCase = SearchBooksUseCase(repository: repository)

        let books = try await useCase.execute(query: "  swift  ", maxResults: 5)

        #expect(repository.receivedQuery == "swift")
        #expect(repository.receivedMaxResults == 5)
        #expect(books == repository.result)
    }

    @Test func emptyQueryDoesNotCallTheRepository() async throws {
        let repository = BookSearchingMock()
        let useCase = SearchBooksUseCase(repository: repository)

        let books = try await useCase.execute(query: "   ")

        #expect(books.isEmpty)
        #expect(repository.receivedQuery == nil)
    }

    @Test func localReadingMetadataHasSafeDefaults() {
        let book = Book(id: "book-3", title: "Domain Driven Design")

        #expect(book.status == .toRead)
        #expect(!book.isFavorite)
        #expect(book.currentProgress == 0)
        #expect(book.author.isEmpty)
    }

    @Test func cacheFirstRepositorySkipsRemoteWhenResultIsCached() async throws {
        let remote = BookSearchingMock()
        let cache = BookSearchCacheMock()
        let cachedBook = Book(id: "cached", title: "Cached Swift")
        cache.values["search:swift:20"] = [cachedBook]
        let repository = CacheFirstBookSearching(remote: remote, cache: cache)

        let books = try await repository.searchBooks(query: " Swift ", maxResults: 20)

        #expect(books == [cachedBook])
        #expect(remote.searchCallCount == 0)
    }

    @Test func cacheFirstRepositoryStoresFreshRemoteResult() async throws {
        let remote = BookSearchingMock()
        let cache = BookSearchCacheMock()
        let repository = CacheFirstBookSearching(remote: remote, cache: cache)

        let books = try await repository.searchBooks(query: "Swift", maxResults: 20)

        #expect(books == remote.result)
        #expect(remote.searchCallCount == 1)
        #expect(cache.values["search:swift:20"] == remote.result)
    }


}

private final class BookSearchingMock: BookSearching, @unchecked Sendable {
    let result = [Book(id: "1", title: "Swift")]
    private(set) var receivedQuery: String?
    private(set) var receivedMaxResults: Int?
    private(set) var searchCallCount = 0

    func searchBooks(query: String, maxResults: Int) async throws -> [Book] {
        searchCallCount += 1
        receivedQuery = query
        receivedMaxResults = maxResults
        return result
    }

    func findBook(isbn: String) async throws -> Book {
        result[0]
    }
}

private final class BookSearchCacheMock: BookSearchCaching, @unchecked Sendable {
    var values: [String: [Book]] = [:]

    func books(for key: String) -> [Book]? {
        values[key]
    }

    func store(_ books: [Book], for key: String) {
        values[key] = books
    }
}

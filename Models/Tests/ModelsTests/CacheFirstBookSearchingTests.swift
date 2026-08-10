import Foundation
import Testing
@testable import Models

struct CacheFirstBookSearchingTests {
    
    @Test func searchBooks_whenNotCached_callsRemoteAndStoresInCache() async throws {
        let remote = MockBookSearching()
        let cache = MockBookSearchCaching()
        let sut = CacheFirstBookSearching(remote: remote, cache: cache)
        
        let query = "swift"
        let books = try await sut.searchBooks(query: query, maxResults: 10)
        
        #expect(remote.searchCallCount == 1)
        #expect(cache.storeCallCount == 1)
        #expect(books.first?.id == "remote-1")
    }
    
    @Test func searchBooks_whenCached_returnsFromCacheAndDoesNotCallRemote() async throws {
        let remote = MockBookSearching()
        let cache = MockBookSearchCaching()
        
        let cachedBook = Book(
            id: "cached-1",
            title: "Cached Swift",
            authors: [],
            pageCount: 100,
            coverURL: nil,
            publishedDate: nil,
            description: nil,
            isbn13: nil
        )
        cache.storedBooks["search:swift:10"] = [cachedBook]
        
        let sut = CacheFirstBookSearching(remote: remote, cache: cache)
        
        let query = "swift"
        let books = try await sut.searchBooks(query: query, maxResults: 10)
        
        #expect(remote.searchCallCount == 0)
        #expect(cache.storeCallCount == 0)
        #expect(books.first?.id == "cached-1")
    }
}

private final class MockBookSearching: BookSearching, @unchecked Sendable {
    var searchCallCount = 0
    
    func searchBooks(query: String, maxResults: Int) async throws -> [Book] {
        searchCallCount += 1
        return [
            Book(
                id: "remote-1",
                title: "Remote Swift",
                authors: [],
                pageCount: 200,
                coverURL: nil,
                publishedDate: nil,
                description: nil,
                isbn13: nil
            )
        ]
    }
    
    func findBook(isbn: String) async throws -> Book {
        throw CacheFirstBookSearchingError.bookNotFound
    }
}

private final class MockBookSearchCaching: BookSearchCaching, @unchecked Sendable {
    var storeCallCount = 0
    var storedBooks: [String: [Book]] = [:]
    
    func books(for key: String) -> [Book]? {
        storedBooks[key]
    }
    
    func store(_ books: [Book], for key: String) {
        storeCallCount += 1
        storedBooks[key] = books
    }
}

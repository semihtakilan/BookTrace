import Foundation
import Testing
@testable import Models

struct GoogleBooksMappingTests {
    @Test func mapsVolumeAndUpgradesCoverURLToHTTPS() throws {
        let book = try decodeBook("""
        {"id":"book-1","volumeInfo":{"title":"Clean Code","authors":["Robert C. Martin"],"pageCount":464,"imageLinks":{"thumbnail":"http://books.google.com/cover.jpg"},"industryIdentifiers":[{"type":"ISBN_13","identifier":"9780132350884"}]}}
        """)

        #expect(book.id == "book-1")
        #expect(book.title == "Clean Code")
        #expect(book.authors == ["Robert C. Martin"])
        #expect(book.coverURL?.absoluteString == "https://books.google.com/cover.jpg")
        #expect(book.isbn13 == "9780132350884")
    }

    @Test func missingCoverAndAuthorsNeverBreakMapping() throws {
        let book = try decodeBook("{\"id\":\"book-2\",\"volumeInfo\":{\"title\":\"Untitled\"}}")

        #expect(book.coverURL == nil)
        #expect(book.authors.isEmpty)
    }

    @Test func emptySearchResultDecodesAsAnEmptyList() throws {
        let result = try JSONDecoder().decode(
            BookSearchResult.self,
            from: Data("{\"totalItems\":0}".utf8)
        )

        #expect(result.items.isEmpty)
        #expect(result.totalItems == 0)
    }

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

    private func decodeBook(_ json: String) throws -> Book {
        try JSONDecoder().decode(Book.self, from: Data(json.utf8))
    }
}

private final class BookSearchingMock: BookSearching, @unchecked Sendable {
    let result = [Book(id: "1", title: "Swift")]
    private(set) var receivedQuery: String?
    private(set) var receivedMaxResults: Int?

    func searchBooks(query: String, maxResults: Int) async throws -> [Book] {
        receivedQuery = query
        receivedMaxResults = maxResults
        return result
    }

    func findBook(isbn: String) async throws -> Book {
        result[0]
    }
}

//
//  OpenLibraryResponseTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation
import Models
import Testing
@testable import BookTrace

@Suite struct OpenLibraryResponseTests {

    private func decode<Value: Decodable>(_ type: Value.Type, from json: String) throws -> Value {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: Data(json.utf8))
    }

    @Test func aSearchResultBecomesABookWithASourcePrefixedIdentifier() throws {
        let response = try decode(OpenLibrarySearchResponse.self, from: """
        {"docs": [{
            "key": "/works/OL8193416W",
            "title": "The Picture of Dorian Gray",
            "author_name": ["Oscar Wilde"],
            "cover_i": 14314858,
            "first_publish_year": 1890,
            "number_of_pages_median": 246
        }]}
        """)

        let books = response.toBookReferences()
        let book = try #require(books.first)

        #expect(book.id == "ol:/works/OL8193416W")
        #expect(book.source == .openLibrary)
        #expect(book.title == "The Picture of Dorian Gray")
        #expect(book.authors == ["Oscar Wilde"])
        #expect(book.pageCount == 246)
        #expect(book.publishedDate == "1890")
        // Kapak, ISBN yolundan değil kapak kimliğinden kuruluyor: ISBN yolu
        // IP başına beş dakikada 100 istekle sınırlı.
        #expect(book.coverURL?.absoluteString == "https://covers.openlibrary.org/b/id/14314858-M.jpg")
    }

    @Test func recordsWithoutATitleOrKeyAreDropped() throws {
        let response = try decode(OpenLibrarySearchResponse.self, from: """
        {"docs": [
            {"key": "/works/OL1W", "title": "Kept"},
            {"key": "/works/OL2W", "title": "   "},
            {"title": "No key"}
        ]}
        """)

        #expect(response.toBookReferences().map(\.title) == ["Kept"])
    }

    @Test func anEmptyPayloadIsAnEmptyListRatherThanAFailure() throws {
        #expect(try decode(OpenLibrarySearchResponse.self, from: "{}").toBookReferences().isEmpty)
    }

    /// Open Library açıklamayı hem düz dize hem de sarmalanmış nesne olarak
    /// döndürüyor; ikisi de okunabilmeli.
    @Test func aDescriptionIsReadInBothOfItsShapes() throws {
        let asObject = try decode(OpenLibraryWork.self, from: """
        {"key": "/works/OL1W", "description": {"type": "/type/text", "value": "Wrapped."}}
        """)
        let asString = try decode(OpenLibraryWork.self, from: """
        {"key": "/works/OL1W", "description": "Plain."}
        """)

        #expect(asObject.toDomain()?.description == "Wrapped.")
        #expect(asString.toDomain()?.description == "Plain.")
    }

    /// Ekranda ham Markdown görünmemeli — ve bağlantı adresleri, vurgu
    /// temizliği yüzünden bozulmamalı.
    @Test func markdownIsReducedToPlainTextWithoutManglingLinkText() {
        let source = """
        **The Picture of Dorian Gray** is a _philosophical_ novel.

        ----------

        (Source: [Wikipedia](https://en.wikipedia.org/wiki/The_Picture_of_Dorian_Gray))
        """

        let text = try! #require(OpenLibraryWork.plainText(source))

        #expect(text.contains("The Picture of Dorian Gray is a philosophical novel."))
        #expect(text.contains("(Source: Wikipedia)"))
        #expect(!text.contains("http"))
        #expect(!text.contains("["))
        #expect(!text.contains("--------"))
    }

    @Test func aReferenceStyleLinkKeepsItsTextToo() {
        #expect(OpenLibraryWork.plainText("See [the notes][1] for more.") == "See the notes for more.")
    }

    @Test func anEmptyDescriptionIsReportedAsMissingRatherThanBlank() {
        #expect(OpenLibraryWork.plainText("   \n\n  ") == nil)
    }

    /// Konular kırpılıyor: bazı eserlerde yüzlerce konu var ve hepsini kategori
    /// önerisi olarak sunmak listeyi kullanılamaz hâle getirir.
    @Test func onlyTheFirstFewSubjectsAreKept() throws {
        let subjects = (1...30).map { "\"Subject \($0)\"" }.joined(separator: ",")
        let work = try decode(OpenLibraryWork.self, from: """
        {"key": "/works/OL1W", "subjects": [\(subjects)]}
        """)

        #expect(work.toDomain()?.subjects.count == 8)
    }

    /// Kütüphane sınıflandırma artıkları kategori adı olmaya uygun değil.
    @Test func classificationArtefactsAreDroppedFromTheSubjects() {
        let subjects = OpenLibraryWork.presentableSubjects([
            "Fiction",
            "British and irish fiction (fictional works by one author)",
            "Conduct of life",
            "Fantasy fiction",
            "Detective and mystery stories, english, english fiction translations"
        ])

        #expect(subjects == ["Fiction", "Conduct of life", "Fantasy fiction"])
    }

    /// Bazı eserlerde yalnızca bu tür etiketler var; hepsini atmak kitabı
    /// konusuz bırakırdı.
    @Test func aWorkWithNothingButArtefactsKeepsThemRatherThanShowingNone() {
        let subjects = OpenLibraryWork.presentableSubjects([
            "British and irish fiction (fictional works by one author)",
            "Detective and mystery stories, english, english fiction translations"
        ])

        #expect(subjects.count == 2)
    }

    /// Barkod yolu baskı kaydından geçiyor; kimlik esere bağlanıyor ki aynı
    /// kitabın arama sonucundan gelen hâliyle tek kayıt olsun.
    @Test func anEditionIsIdentifiedByItsWorkSoBothPathsAgree() throws {
        let edition = try decode(OpenLibraryEdition.self, from: """
        {
            "key": "/books/OL23140636M",
            "title": "Crime and punishment",
            "number_of_pages": 671,
            "publish_date": "2003",
            "covers": [14935910],
            "works": [{"key": "/works/OL166894W"}]
        }
        """)

        let book = try #require(edition.toDomain(isbn: "9780140449136"))

        #expect(book.id == "ol:/works/OL166894W")
        #expect(book.title == "Crime and punishment")
        #expect(book.pageCount == 671)
        #expect(book.isbn13 == "9780140449136")
    }

    @Test func anEditionWithoutAWorkFallsBackToItsOwnKey() throws {
        let edition = try decode(OpenLibraryEdition.self, from: """
        {"key": "/books/OL1M", "title": "Standalone"}
        """)

        #expect(edition.toDomain(isbn: "123")?.id == "ol:/books/OL1M")
    }
}

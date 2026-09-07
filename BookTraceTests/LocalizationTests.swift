//
//  LocalizationTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation
import Testing
@testable import BookTrace

@MainActor
struct LocalizationTests {
    @Test(arguments: ["en", "de", "tr"])
    func countsUseTheSelectedLanguagesPluralRules(_ language: String) throws {
        let bundle = try localizedBundle(language)
        let locale = Locale(identifier: language)
        let singular = ["en": "1 book", "de": "1 Buch", "tr": "1 kitap"]
        let plural = ["en": "2 books", "de": "2 Bücher", "tr": "2 kitap"]
        let zero = ["en": "0 books", "de": "0 Bücher", "tr": "0 kitap"]
        let format = bundle.localizedString(forKey: "%lld books", value: nil, table: nil)
        #expect(String(format: format, locale: locale, arguments: [Int64(1)]) == singular[language])
        #expect(String(format: format, locale: locale, arguments: [Int64(2)]) == plural[language])
        #expect(String(format: format, locale: locale, arguments: [Int64(0)]) == zero[language])
    }

    @Test func germanSingularStreakMinutesAndRemainingPages() throws {
        let bundle = try localizedBundle("de")
        let cases = [
            "%lld days in a row": "1 Tag in Folge",
            "%lld minutes. The world can wait.": "1 Minute. Die Welt kann warten.",
            "This book only has %lld pages left.": "In diesem Buch ist nur noch 1 Seite übrig."
        ]
        for (key, expected) in cases {
            let format = bundle.localizedString(forKey: key, value: nil, table: nil)
            #expect(String(format: format, locale: Locale(identifier: "de"), arguments: [Int64(1)]) == expected)
        }
    }

    @Test func pageTotalsChoosePluralFromTheSecondArgument() throws {
        let bundle = try localizedBundle("en")
        let format = bundle.localizedString(forKey: "%lld of %lld pages", value: nil, table: nil)
        #expect(String(format: format, locale: Locale(identifier: "en"), arguments: [Int64(0), Int64(1)]) == "0 of 1 page")
        #expect(String(format: format, locale: Locale(identifier: "en"), arguments: [Int64(1), Int64(2)]) == "1 of 2 pages")
    }

    private func localizedBundle(_ language: String) throws -> Bundle {
        let app = Bundle(for: BookDetailViewModel.self)
        let path = try #require(app.path(forResource: language, ofType: "lproj"))
        return try #require(Bundle(path: path))
    }
}

//
//  BookAmbienceTests.swift
//  ModelsTests
//
//  Created by Semih TAKILAN on 04.09.2026.
//

import Foundation
import Testing
@testable import Models

struct BookAmbienceTests {

    private func book(subjects: [String] = [], title: String = "Untitled") -> BookReference {
        BookReference(id: "id", title: title, subjects: subjects)
    }

    @Test func googleBooksStyleCategoriesResolve() {
        #expect(BookAmbience.resolve(for: book(subjects: ["Fiction / Science Fiction / Space Opera"])) == .scienceFiction)
        #expect(BookAmbience.resolve(for: book(subjects: ["Biography & Autobiography / Artists"])) == .biography)
        #expect(BookAmbience.resolve(for: book(subjects: ["Computers / Programming / General"])) == .technology)
    }

    @Test func openLibraryStyleSubjectListsResolve() {
        #expect(BookAmbience.resolve(for: book(subjects: ["Detective and mystery stories", "English fiction"])) == .mystery)
        #expect(BookAmbience.resolve(for: book(subjects: ["World War, 1939-1945", "History"])) == .history)
    }

    @Test func aMoreSpecificSubjectWinsOverPlainFiction() {
        // Neredeyse her kurgu kitabında "Fiction" da geçiyor; sıralama olmasa
        // bilim kurgu da polisiye de düz romana düşerdi.
        let subjects = ["Fiction", "Science fiction", "American literature"]

        #expect(BookAmbience.resolve(for: book(subjects: subjects)) == .scienceFiction)
    }

    @Test func theTitleIsTheFallbackWhenNoSubjectIsRecognised() {
        #expect(BookAmbience.resolve(for: book(subjects: ["Unclassified"], title: "A Short History of Nearly Everything")) == .history)
        #expect(BookAmbience.resolve(for: book(subjects: [], title: "Collected Poems")) == .poetry)
    }

    @Test func anUnknownBookSettlesOnTheLiteraryAmbience() {
        #expect(BookAmbience.resolve(for: book(subjects: [], title: "Untitled")) == .literary)
        #expect(BookAmbience.resolve(for: book(subjects: ["Miscellaneous"], title: "")) == .literary)
    }

    @Test func resolutionIsStableAcrossCalls() {
        // Anahtarlar sözlükte tutulurken aynı kitap iki çağrıda iki farklı
        // havaya düşebiliyordu; sıra artık dizinin kendisinde.
        let subject = book(subjects: ["Fiction", "Philosophy", "History"])
        let results = (0..<20).map { _ in BookAmbience.resolve(for: subject) }

        #expect(Set(results).count == 1)
    }
}

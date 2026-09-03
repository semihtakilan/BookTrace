//
//  CategoryTests.swift
//  ModelsTests
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation
import Testing
@testable import Models

struct CategoryTests {

    @Test func theSameTagWrittenDifferentlyResolvesToOneIdentity() {
        #expect(Models.Category(name: "Deep Work").id == Models.Category(name: "deep-work").id)
        #expect(Models.Category(name: " Book Club ").id == Models.Category(name: "book club").id)
    }

    @Test func repeatedSeparatorsCollapseIntoOne() {
        // "Book  Club" daha önce `book--club` üretip ikinci bir etiket doğuruyordu.
        #expect(Models.Category(name: "Book  Club").id == "book-club")
        #expect(Models.Category(name: "Book - Club").id == "book-club")
    }

    @Test func theDisplayNameKeepsTheUsersOwnSpelling() {
        let category = Models.Category(name: "  Deep Work  ")

        #expect(category.name == "Deep Work")
        #expect(category.id == "deep-work")
    }
}

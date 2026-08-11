//
//  BooksViewModel.swift
//  Books
//
//  Created by Semih TAKILAN on 06.08.2026.
//

import Foundation
import Observation
import Models

@MainActor
@Observable
final class BooksViewModel {
    var nowReading: Book?
    var libraryBooks: [ReadingStatus: [Book]] = [:]
    var ownershipBooks: [OwnershipStatus: [Book]] = [:]
    var categoryBooks: [Models.Category: [Book]] = [:]
    
    var errorMessage: String?
    
    @ObservationIgnored
    private let bookRepository: any BookRepository

    init(bookRepository: any BookRepository) {
        self.bookRepository = bookRepository
    }

    func load() {
        do {
            let books = try bookRepository.fetchBooks()
            
            // Section 1: Now Reading
            nowReading = books.first { $0.status == .reading }
            
            // Section 2: Library
            libraryBooks = Dictionary(grouping: books, by: { $0.status })
            
            // Section 3: Ownership
            ownershipBooks = Dictionary(grouping: books, by: { $0.ownership })
            
            // Section 4: Categories
            var catBooks: [Models.Category: [Book]] = [:]
            for book in books {
                for category in book.categories {
                    catBooks[category, default: []].append(book)
                }
            }
            categoryBooks = catBooks
            
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

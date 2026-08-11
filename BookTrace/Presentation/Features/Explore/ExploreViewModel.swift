//
//  ExploreViewModel.swift
//  Explore
//
//  Created by Semih TAKILAN on 11.08.2026.
//

import Foundation
import Observation
import Models

@MainActor
@Observable
final class ExploreViewModel {
    var searchText: String = ""
    var searchResults: [Book] = []
    var isSearching: Bool = false
    var errorMessage: String?
    
    @ObservationIgnored
    private let bookSearching: any BookSearching
    
    init(bookSearching: any BookSearching) {
        self.bookSearching = bookSearching
    }
    
    func performSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        errorMessage = nil
        
        do {
            searchResults = try await bookSearching.searchBooks(query: query, maxResults: 20)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSearching = false
    }
    
    func handleBarcodeScan(isbn: String) async {
        isSearching = true
        errorMessage = nil
        
        do {
            let book = try await bookSearching.findBook(isbn: isbn)
            searchResults = [book]
            searchText = isbn
        } catch {
            errorMessage = error.localizedDescription
            searchResults = []
        }
        
        isSearching = false
    }
}

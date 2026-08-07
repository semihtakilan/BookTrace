//
//  HomeViewModel.swift
//  BookTrace
//
//  Created by Semih TAKILAN on 31.07.2026.
//

import Foundation
import Observation
import Models

struct BookCategory: Identifiable, Sendable {
    let id: String
    let displayName: String
    let books: [Book]
}

@MainActor
@Observable
final class HomeViewModel {
    private(set) var state: ViewState<[BookCategory]> = .idle

    @ObservationIgnored
    private let bookSearching: any BookSearching

    private let categories: [(key: String, displayName: String)] = [
        ("subject:fiction", "Kurgu"),
        ("subject:science fiction", "Bilim Kurgu"),
        ("subject:mystery", "Gizem"),
        ("fantasy", "Fantastik")
    ]

    init(bookSearching: any BookSearching) {
        self.bookSearching = bookSearching
    }

    func load() async {
        if case .loaded = state { return }
        if case .loading = state { return }
        
        state = .loading
        do {
            // Google Books başlangıçta dört eşzamanlı arama yerine sıralı çağrılır;
            // bu, geçici 503/rate-limit cevaplarının olasılığını azaltır.
            var results: [BookCategory] = []
            for category in categories {
                let books = try await bookSearching.searchBooks(query: category.key, maxResults: 10)
                results.append(
                    BookCategory(id: category.key, displayName: category.displayName, books: books)
                )
            }
            state = .loaded(results)
        } catch {
            state = .failed(userFacingMessage(for: error))
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        error.localizedDescription
    }
}

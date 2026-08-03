//
//  HomeViewModel.swift
//  BookTrace
//
//  Created by Semih TAKILAN on 31.07.2026.
//

import Foundation
import Observation
import FactoryKit
import Models

struct BookCategory: Identifiable, Sendable {
    let id: String
    let displayName: String
    let books: [BookReference]
}

@MainActor
@Observable
final class HomeViewModel {
    private(set) var state: ViewState<[BookCategory]> = .idle

    @ObservationIgnored
    @Injected(\.bookService)
    private var bookService

    private let categories: [(key: String, displayName: String)] = [
        ("fiction", "Kurgu"),
        ("science_fiction", "Bilim Kurgu"),
        ("mystery", "Gizem"),
        ("fantasy", "Fantastik")
    ]

    func load() async {
        state = .loading
        do {
            let results = try await withThrowingTaskGroup(of: BookCategory.self) { group in
                for category in categories {
                    group.addTask { [bookService] in
                        let books = try await bookService.fetchSubject(category.key, limit: 10)
                        return BookCategory(id: category.key, displayName: category.displayName, books: books)
                    }
                }
                var collected: [BookCategory] = []
                for try await category in group {
                    collected.append(category)
                }
                return collected
            }
            let order = categories.map(\.key)
            state = .loaded(results.sorted {
                (order.firstIndex(of: $0.id) ?? 0) < (order.firstIndex(of: $1.id) ?? 0)
            })
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

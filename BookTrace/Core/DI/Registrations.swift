//
//  Registrations.swift
//  DI
//
//  Created by Semih TAKILAN on 30.07.2026.
//

import FactoryKit
import Models
import NetworkKit
import NetworkRegistration

extension Container: @retroactive AutoRegistering {

    public func autoRegister() {
        NetworkRegistrations.register()
    }
}

extension Container {
    var bookSearching: Factory<any BookSearching> {
        self {
            CacheFirstBookSearching(
                remote: GoogleBooksService(networkService: self.networkService()),
                cache: self.bookSearchCache()
            )
        }
        .singleton
    }

    var bookSearchCache: Factory<any BookSearchCaching> {
        self { BookSearchCache() }.singleton
    }

    @MainActor
    var bookRepository: Factory<any BookRepository> {
        self {
            fatalError("BookRepository is registered when AppDependencies creates the SwiftData container.")
        }
        .singleton
    }

    @MainActor
    var booksViewModel: Factory<BooksViewModel> {
        self {
            BooksViewModel(bookRepository: self.bookRepository())
        }
    }

    @MainActor
    var exploreViewModel: Factory<ExploreViewModel> {
        self {
            ExploreViewModel(bookSearching: self.bookSearching())
        }
    }
}

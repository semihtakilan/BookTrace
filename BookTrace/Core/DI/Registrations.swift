//
//  Registrations.swift
//  BookTrace
//
//  Created by Batuhan Baran on 30.07.2026.
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
            GoogleBooksService(networkService: self.networkService())
        }
        .singleton
    }

    @MainActor
    var bookRepository: Factory<any BookRepository> {
        self {
            fatalError("BookRepository is registered when AppDependencies creates the SwiftData container.")
        }
        .singleton
    }

    @MainActor
    var homeViewModel: Factory<HomeViewModel> {
        self {
            HomeViewModel(bookSearching: self.bookSearching())
        }
    }
}

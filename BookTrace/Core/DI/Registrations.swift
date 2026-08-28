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
    var libraryRepository: Factory<any LibraryRepository> {
        self {
            fatalError("LibraryRepository is registered when AppDependencies creates the SwiftData container.")
        }
        .singleton
    }

    @MainActor
    var appSettings: Factory<AppSettings> {
        self { AppSettings() }.singleton
    }

    @MainActor
    var libraryChangeNotifier: Factory<LibraryChangeNotifier> {
        self { LibraryChangeNotifier() }.singleton
    }

    @MainActor
    var viewModelFactory: Factory<ViewModelFactory> {
        self {
            ViewModelFactory(
                libraryRepository: self.libraryRepository(),
                bookSearching: self.bookSearching(),
                bookSearchCache: self.bookSearchCache(),
                settings: self.appSettings()
            )
        }
        .singleton
    }
}

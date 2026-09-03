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
    /// İki kaynağı birleştiren uzak katman.
    ///
    /// Cache sarmalaması burada değil composition root'ta yapılıyor: mağaza
    /// `ModelContainer`'a bağlı ve o açılamayabilir, Factory kayıtları ise hata
    /// fırlatamıyor.
    var remoteBookSearching: Factory<any BookSearching & BookDetailFetching> {
        self {
            let openLibrary = OpenLibraryService(networkService: self.networkService())
            return HybridBookSearching(
                primary: openLibrary,
                primaryDetail: openLibrary,
                fallback: self.googleBooks(),
                budget: self.googleBooksBudget()
            )
        }
        .singleton
    }

    var googleBooks: Factory<GoogleBooksService> {
        self { GoogleBooksService(networkService: self.networkService()) }.singleton
    }

    var googleBooksBudget: Factory<DailyRequestBudget> {
        self { DailyRequestBudget() }.singleton
    }

    @MainActor
    var appSettings: Factory<AppSettings> {
        self { AppSettings() }.singleton
    }

    @MainActor
    var libraryChangeNotifier: Factory<LibraryChangeNotifier> {
        self { LibraryChangeNotifier() }.singleton
    }
}

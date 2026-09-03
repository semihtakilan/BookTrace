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
    /// Uzak kaynak. Cache sarmalaması burada değil composition root'ta yapılıyor:
    /// mağaza `ModelContainer`'a bağlı ve o açılamayabilir, Factory kayıtları ise
    /// hata fırlatamıyor.
    var remoteBookSearching: Factory<any BookSearching> {
        self { GoogleBooksService(networkService: self.networkService()) }.singleton
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

//
//  AppDependencies.swift
//  DI
//
//  Created by Semih TAKILAN on 07.08.2026.
//

import FactoryKit
import Models
import SwiftData

/// Uygulamanın composition root'u.
///
/// Factory kayıtları yalnızca burada çözülür; Presentation katmanı somut veri
/// servislerini veya DI container'ını bilmeden, ihtiyaç duyduğu bağımlılıkları
/// initializer veya environment üzerinden alır.
///
/// Kalıcı mağaza burada kurulur ve kurulamazsa hata yukarı fırlatılır —
/// `fatalError` ile çökmek kullanıcıya hiçbir kurtarma yolu bırakmıyordu.
@MainActor
struct AppDependencies {
    let viewModelFactory: ViewModelFactory
    let libraryChangeNotifier: LibraryChangeNotifier
    let settings: AppSettings
    let modelContainer: ModelContainer

    init(container: Container) throws {
        modelContainer = try LocalStore.makeContainer()
        libraryChangeNotifier = container.libraryChangeNotifier()
        settings = container.appSettings()

        // Repository, mağazaya bağlı olduğu için Factory'de kayıtlı değil:
        // varsayılan gövdesi `fatalError` olan bir kayıt, container sıfırlandığı
        // anda uygulamayı çökertirdi. Burada kurulup elden geçiriliyor.
        // Kimlik biçimi değişti; kayıtlı kitaplar yeni biçime taşınıyor.
        BookIdentifierMigration.run(in: modelContainer.mainContext)

        let repository = LocalLibraryRepositoryImpl(
            modelContext: modelContainer.mainContext,
            changeNotifier: libraryChangeNotifier
        )

        // Cache mağazası açılamazsa uygulama yine çalışmalı: her istek ağa
        // gider, kütüphane etkilenmez. Bu yüzden hata yukarı fırlatılmıyor.
        let cacheStore: any BookCacheStore
        if let cacheContainer = try? BookCacheStorage.makeContainer() {
            let store = SwiftDataBookCacheStore(modelContainer: cacheContainer)
            cacheStore = store
            Task.detached(priority: .utility) { await store.prune() }
        } else {
            cacheStore = DisabledBookCacheStore()
        }

        let bookSearching = CachedBookSearching(
            remote: container.remoteBookSearching(),
            store: cacheStore
        )

        viewModelFactory = ViewModelFactory(
            libraryRepository: repository,
            bookSearching: bookSearching,
            bookDetailFetching: bookSearching,
            bookCacheStore: cacheStore,
            googleBooksBudget: container.googleBooksBudget(),
            settings: settings
        )
    }
}

//
//  AppDependencies.swift
//  DI
//
//  Created by Semih TAKILAN on 07.08.2026.
//

import FactoryKit
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
        let repository = LocalLibraryRepositoryImpl(
            modelContext: modelContainer.mainContext,
            changeNotifier: libraryChangeNotifier
        )

        viewModelFactory = ViewModelFactory(
            libraryRepository: repository,
            bookSearching: container.bookSearching(),
            bookSearchCache: container.bookSearchCache(),
            settings: settings
        )
    }
}

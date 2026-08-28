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
@MainActor
struct AppDependencies {
    let viewModelFactory: ViewModelFactory
    let libraryChangeNotifier: LibraryChangeNotifier
    let modelContainer: ModelContainer

    init(container: Container) {
        let persistentContainer: ModelContainer
        do {
            persistentContainer = try ModelContainer(
                for: LocalLibraryEntryModel.self,
                LocalReadingSessionModel.self,
                LocalCategoryModel.self
            )
        } catch {
            fatalError("Unable to create the local book library: \(error)")
        }

        modelContainer = persistentContainer
        libraryChangeNotifier = container.libraryChangeNotifier()

        let repository = LocalLibraryRepositoryImpl(
            modelContext: persistentContainer.mainContext,
            changeNotifier: libraryChangeNotifier
        )
        container.libraryRepository.register {
            repository
        }

        viewModelFactory = container.viewModelFactory()
    }
}

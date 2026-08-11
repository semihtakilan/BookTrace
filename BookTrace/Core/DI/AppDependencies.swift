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
/// initializer üzerinden alır.
@MainActor
struct AppDependencies {
    let booksViewModel: BooksViewModel
    let exploreViewModel: ExploreViewModel
    let modelContainer: ModelContainer

    init(container: Container) {
        let persistentContainer: ModelContainer
        do {
            persistentContainer = try ModelContainer(for: LocalBookModel.self, LocalCategoryModel.self)
        } catch {
            fatalError("Unable to create the local book library: \(error)")
        }

        modelContainer = persistentContainer
        let repository = LocalBookRepositoryImpl(modelContext: persistentContainer.mainContext)
        container.bookRepository.register {
            repository
        }

        booksViewModel = container.booksViewModel()
        exploreViewModel = container.exploreViewModel()
    }
}

//
//  AppDependencies.swift
//  BookTrace
//

import FactoryKit

/// Uygulamanın composition root'u.
///
/// Factory kayıtları yalnızca burada çözülür; Presentation katmanı somut veri
/// servislerini veya DI container'ını bilmeden, ihtiyaç duyduğu bağımlılıkları
/// initializer üzerinden alır.
@MainActor
struct AppDependencies {
    let homeViewModel: HomeViewModel

    init(container: Container) {
        homeViewModel = container.homeViewModel()
    }
}

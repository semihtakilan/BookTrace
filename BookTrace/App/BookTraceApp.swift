//
//  BookTraceApp.swift
//  App
//
//  Created by Semih TAKILAN on 29.07.2026.
//

import SwiftUI
import SwiftData
import FactoryKit

@main
struct BookTraceApp: App {
    @State private var startup: StartupState

    init() {
        Container.shared.autoRegister()
        _startup = State(initialValue: .make())
    }

    var body: some Scene {
        WindowGroup {
            switch startup {
            case .ready(let dependencies):
                ApplicationRootView(
                    viewModelFactory: dependencies.viewModelFactory,
                    libraryChangeNotifier: dependencies.libraryChangeNotifier,
                    settings: dependencies.settings
                )
                    .modelContainer(dependencies.modelContainer)

            case .storageUnavailable(let reason):
                StorageUnavailableView(reason: reason) {
                    startup = .make()
                }
            }
        }
    }
}

/// Açılışın iki olası sonucu.
///
/// Kalıcı mağaza açılamadığında uygulama çökmek yerine kullanıcıya bir çıkış
/// yolu sunar: yeniden dene, ya da son çare olarak yerel veriyi sıfırla.
enum StartupState {
    case ready(AppDependencies)
    case storageUnavailable(String)

    @MainActor
    static func make() -> StartupState {
        do {
            return .ready(try AppDependencies(container: .shared))
        } catch {
            return .storageUnavailable(error.localizedDescription)
        }
    }
}

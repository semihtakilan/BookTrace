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
    private let dependencies: AppDependencies

    init() {
        Container.shared.autoRegister()
        dependencies = AppDependencies(container: .shared)
    }

    var body: some Scene {
        WindowGroup {
            ApplicationRootView(
                viewModelFactory: dependencies.viewModelFactory,
                libraryChangeNotifier: dependencies.libraryChangeNotifier,
                settings: dependencies.settings
            )
                .modelContainer(dependencies.modelContainer)
        }
    }
}

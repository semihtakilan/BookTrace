//
//  BookTraceApp.swift
//  BookTrace
//
//  Created by Batuhan Baran on 29.07.2026.
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
            ApplicationRootView(homeViewModel: dependencies.homeViewModel)
                .modelContainer(dependencies.modelContainer)
        }
    }
}

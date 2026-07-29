//
//  AppRouteTypeManager.swift
//  BookTrace
//
//  Created by Batuhan Baran on 29.07.2026.
//

import SwiftUI
import NavigatorUI

@MainActor
@Observable
final class AppRouteTypeManager {
    private(set) var rootType: AppRootType = .splash
    var selectedTab: AppTab = .home

    let navigator = Navigator(configuration: .init(
        restorationKey: nil,
        executionDelay: 0.4,
        verbosity: .warning,
        autoDestinationMode: true
    ))

    @ObservationIgnored
    private var didBootstrap = false

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true

        async let minimumDisplay: Void = Task.sleep(for: .seconds(1))
        async let realWork: Void = performStartupTasks()   // ileride auth/cache/config

        _ = try? await (minimumDisplay, realWork)
        rootType = .tabbed
    }

    private func performStartupTasks() async {
        // şimdilik boş, ileride buraya gerçek iş girer
    }
}

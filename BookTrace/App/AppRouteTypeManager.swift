//
//  AppRouteTypeManager.swift
//  App
//
//  Created by Semih TAKILAN on 29.07.2026.
//

import SwiftUI
import NavigatorUI

@MainActor
@Observable
final class AppRouteTypeManager {
    private(set) var rootType: AppRootType = .splash
    var selectedTab: AppTab = .books

    let booksNavigator = Navigator(configuration: .init(
        restorationKey: nil,
        executionDelay: 0.4,
        verbosity: .warning,
        autoDestinationMode: true
    ))
    let exploreNavigator = Navigator(configuration: .init(
        restorationKey: nil,
        executionDelay: 0.4,
        verbosity: .warning,
        autoDestinationMode: true
    ))
    let profileNavigator = Navigator(configuration: .init(
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

        await performStartupTasks()
        rootType = .tabbed
    }

    /// İleride auth, uzak yapılandırma veya cache ısıtma buraya girer.
    ///
    /// Şu an gerçek bir iş yok; bu yüzden splash da görünmüyor. Önceden burada
    /// bir saniyelik "minimum gösterim süresi" vardı — uygulama hiçbir şey
    /// beklemezken kullanıcıyı her soğuk başlatmada bir saniye bekletiyordu.
    private func performStartupTasks() async {
    }
}

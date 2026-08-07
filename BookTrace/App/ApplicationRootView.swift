//
//  ApplicationRootView.swift
//  BookTrace
//
//  Created by Batuhan Baran on 30.07.2026.
//

import SwiftUI
import NavigatorUI

struct ApplicationRootView: View {
    @State private var routeManager = AppRouteTypeManager()
    let homeViewModel: HomeViewModel

    var body: some View {
        ApplicationRootContent(routeManager: routeManager, homeViewModel: homeViewModel)
            .task {
                await routeManager.bootstrap()
            }
    }
}

private struct ApplicationRootContent: View {
    @Bindable var routeManager: AppRouteTypeManager
    let homeViewModel: HomeViewModel

    var body: some View {
        Group {
            switch routeManager.rootType {
            case .splash:
                SplashView()
            case .tabbed:
                RootTabView(homeViewModel: homeViewModel)
            }
        }
        .animation(.smooth(duration: 0.4), value: routeManager.rootType)
        .environment(routeManager)
        .navigationRoot(routeManager.navigator)
    }
}

//
//  ApplicationRootView.swift
//  App
//
//  Created by Semih TAKILAN on 29.07.2026.
//

import SwiftUI
import NavigatorUI

struct ApplicationRootView: View {
    @State private var routeManager = AppRouteTypeManager()
    let booksViewModel: BooksViewModel
    let exploreViewModel: ExploreViewModel

    var body: some View {
        ApplicationRootContent(routeManager: routeManager, booksViewModel: booksViewModel, exploreViewModel: exploreViewModel)
            .task {
                await routeManager.bootstrap()
            }
    }
}

private struct ApplicationRootContent: View {
    @Bindable var routeManager: AppRouteTypeManager
    let booksViewModel: BooksViewModel
    let exploreViewModel: ExploreViewModel

    var body: some View {
        Group {
            switch routeManager.rootType {
            case .splash:
                SplashView()
            case .tabbed:
                RootTabView(routeManager: routeManager, booksViewModel: booksViewModel, exploreViewModel: exploreViewModel)
            }
        }
        .animation(.smooth(duration: 0.4), value: routeManager.rootType)
        .environment(routeManager)
    }
}

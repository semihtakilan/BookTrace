//
//  RootTabView.swift
//  BookTrace
//
//  Created by Batuhan Baran on 30.07.2026.
//

import SwiftUI

struct RootTabView: View {
    @Environment(AppRouteTypeManager.self) private var routeManager
    let homeViewModel: HomeViewModel

    var body: some View {
        @Bindable var routeManager = routeManager
        TabView(selection: $routeManager.selectedTab) {
            HomeTab(viewModel: homeViewModel)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)
            ExploreTab()
                .tabItem { Label("Explore", systemImage: "magnifyingglass") }
                .tag(AppTab.explore)
            ProfileTab()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
    }
}

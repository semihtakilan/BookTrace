//
//  RootTabView.swift
//  BookTrace
//
//  Created by Batuhan Baran on 30.07.2026.
//

import SwiftUI
import NavigatorUI

struct RootTabView: View {
    @Environment(AppRouteTypeManager.self) private var routeManager
    let homeViewModel: HomeViewModel

    var body: some View {
        @Bindable var routeManager = routeManager
        TabView(selection: $routeManager.selectedTab) {
            HomeTab(viewModel: homeViewModel)
                .navigationRoot(routeManager.homeNavigator)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)
            ExploreTab()
                .navigationRoot(routeManager.exploreNavigator)
                .tabItem { Label("Explore", systemImage: "magnifyingglass") }
                .tag(AppTab.explore)
            ProfileTab()
                .navigationRoot(routeManager.profileNavigator)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
    }
}

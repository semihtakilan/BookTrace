//
//  RootTabView.swift
//  App
//
//  Created by Semih TAKILAN on 29.07.2026.
//

import SwiftUI
import NavigatorUI

struct RootTabView: View {
    @Bindable var routeManager: AppRouteTypeManager
    let booksViewModel: BooksViewModel

    var body: some View {
        TabView(selection: $routeManager.selectedTab) {
            BooksTab(viewModel: booksViewModel)
                .navigationRoot(routeManager.booksNavigator)
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(AppTab.books)
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

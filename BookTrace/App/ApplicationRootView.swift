//
//  ApplicationRootView.swift
//  App
//
//  Created by Semih TAKILAN on 29.07.2026.
//

import SwiftUI
import NavigatorUI

struct ApplicationRootView: View {
    private let viewModelFactory: ViewModelFactory
    private let libraryChangeNotifier: LibraryChangeNotifier
    private let settings: AppSettings

    @State private var routeManager = AppRouteTypeManager()
    @State private var booksViewModel: BooksViewModel
    @State private var exploreViewModel: ExploreViewModel
    @State private var profileViewModel: ProfileViewModel

    init(
        viewModelFactory: ViewModelFactory,
        libraryChangeNotifier: LibraryChangeNotifier,
        settings: AppSettings
    ) {
        self.viewModelFactory = viewModelFactory
        self.libraryChangeNotifier = libraryChangeNotifier
        self.settings = settings
        _booksViewModel = State(initialValue: viewModelFactory.makeBooksViewModel())
        _exploreViewModel = State(initialValue: viewModelFactory.makeExploreViewModel())
        _profileViewModel = State(initialValue: viewModelFactory.makeProfileViewModel())
    }

    var body: some View {
        ApplicationRootContent(
            routeManager: routeManager,
            booksViewModel: booksViewModel,
            exploreViewModel: exploreViewModel,
            profileViewModel: profileViewModel
        )
        .environment(viewModelFactory)
        .environment(libraryChangeNotifier)
        .environment(settings)
        // Tema ve dil kökten uygulanır; ayar değiştiği anda tüm ekranlar yeniden çizilir.
        .preferredColorScheme(settings.theme.colorScheme)
        .environment(\.locale, settings.resolvedLocale)
        .task {
            await routeManager.bootstrap()
        }
    }
}

private struct ApplicationRootContent: View {
    @Bindable var routeManager: AppRouteTypeManager
    let booksViewModel: BooksViewModel
    let exploreViewModel: ExploreViewModel
    let profileViewModel: ProfileViewModel

    var body: some View {
        Group {
            switch routeManager.rootType {
            case .splash:
                SplashView()
            case .tabbed:
                RootTabView(
                    routeManager: routeManager,
                    booksViewModel: booksViewModel,
                    exploreViewModel: exploreViewModel,
                    profileViewModel: profileViewModel
                )
            }
        }
        .animation(.smooth(duration: 0.4), value: routeManager.rootType)
        .environment(routeManager)
    }
}

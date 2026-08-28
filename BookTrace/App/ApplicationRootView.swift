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

    @State private var routeManager = AppRouteTypeManager()
    @State private var booksViewModel: BooksViewModel
    @State private var exploreViewModel: ExploreViewModel

    init(viewModelFactory: ViewModelFactory, libraryChangeNotifier: LibraryChangeNotifier) {
        self.viewModelFactory = viewModelFactory
        self.libraryChangeNotifier = libraryChangeNotifier
        _booksViewModel = State(initialValue: viewModelFactory.makeBooksViewModel())
        _exploreViewModel = State(initialValue: viewModelFactory.makeExploreViewModel())
    }

    var body: some View {
        ApplicationRootContent(
            routeManager: routeManager,
            booksViewModel: booksViewModel,
            exploreViewModel: exploreViewModel
        )
        .environment(viewModelFactory)
        .environment(libraryChangeNotifier)
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
                RootTabView(
                    routeManager: routeManager,
                    booksViewModel: booksViewModel,
                    exploreViewModel: exploreViewModel
                )
            }
        }
        .animation(.smooth(duration: 0.4), value: routeManager.rootType)
        .environment(routeManager)
    }
}

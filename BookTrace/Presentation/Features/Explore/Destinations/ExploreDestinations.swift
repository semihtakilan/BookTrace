//
//  ExploreDestinations.swift
//  Destinations
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import SwiftUI
import NavigatorUI
import Models

enum ExploreDestinations: NavigationDestination {
    case bookDetail(BookReference)

    var body: some View {
        switch self {
        case .bookDetail(let book):
            BookDetailView(book: book)
        }
    }
}

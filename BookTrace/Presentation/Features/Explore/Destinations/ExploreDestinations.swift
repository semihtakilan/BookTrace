//
//  ExploreDestinations.swift
//  Destinations
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import SwiftUI
import NavigatorUI
import Models

enum ExploreDestinations: Hashable {
    case bookDetail(BookReference)
}

extension ExploreDestinations: @MainActor NavigationDestination {
    var body: some View {
        switch self {
        case .bookDetail(let book):
            BookDetailView(book: book)
        }
    }
}

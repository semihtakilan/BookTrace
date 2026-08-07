//
//  HomeDestinations.swift
//  BookTrace
//
//  Created by Batuhan Baran on 30.07.2026.
//

import SwiftUI
import NavigatorUI
import Models

enum HomeDestinations: NavigationDestination {
    case bookDetail(Book)

    var body: some View {
        switch self {
        case .bookDetail(let book):
            BookDetailView(book: book)
        }
    }
}

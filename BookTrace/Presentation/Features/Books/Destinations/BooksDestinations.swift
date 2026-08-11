//
//  BooksDestinations.swift
//  Destinations
//
//  Created by Semih TAKILAN on 06.08.2026.
//

import SwiftUI
import NavigatorUI
import Models

enum BooksDestinations: NavigationDestination {
    case bookDetail(Book)

    var body: some View {
        switch self {
        case .bookDetail(let book):
            Text("Book Detail for \(book.title)")
        }
    }
}

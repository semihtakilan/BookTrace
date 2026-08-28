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
    case entryDetail(LibraryEntry)
    case readingSession(LibraryEntry)

    var body: some View {
        switch self {
        case .entryDetail(let entry):
            BookLibraryDetailView(entry: entry)
        case .readingSession(let entry):
            ReadingSessionView(entry: entry)
        }
    }

    /// Okuma oturumu tam ekran açılır; sayaç sırasında sekme çubuğu dikkat dağıtmasın.
    var method: NavigationMethod {
        switch self {
        case .entryDetail:    .push
        case .readingSession: .managedCover
        }
    }
}

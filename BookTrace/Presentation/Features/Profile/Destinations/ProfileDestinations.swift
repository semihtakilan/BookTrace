//
//  ProfileDestinations.swift
//  Destinations
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import SwiftUI
import NavigatorUI
import Models

enum ProfileDestinations: Hashable {
    case settings
    case bookDetail(BookReference)
    case readingHistory(Date?)
}

extension ProfileDestinations: @MainActor NavigationDestination {
    var body: some View {
        switch self {
        case .settings:
            SettingsView()
        case .bookDetail(let book):
            JournalBookDestination(book: book)
        case .readingHistory(let day):
            ReadingHistoryView(day: day)
        }
    }
}

/// History belongs to the reader's library, so its book link exposes progress
/// and Continue reading. If the entry disappeared, catalog details still work.
private struct JournalBookDestination: View {
    let book: BookReference
    @Environment(ProfileViewModel.self) private var viewModel

    var body: some View {
        if let entry = viewModel.entries.first(where: { $0.id == book.id }) {
            BookLibraryDetailView(entry: entry)
        } else {
            BookDetailView(book: book)
        }
    }
}

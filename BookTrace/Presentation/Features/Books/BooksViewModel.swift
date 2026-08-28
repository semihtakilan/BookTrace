//
//  BooksViewModel.swift
//  Books
//
//  Created by Semih TAKILAN on 06.08.2026.
//

import Foundation
import Models
import Observation

@MainActor
@Observable
final class BooksViewModel {
    private(set) var entries: [LibraryEntry] = []
    var error: UserFacingError?

    @ObservationIgnored
    private let libraryRepository: any LibraryRepository

    init(libraryRepository: any LibraryRepository) {
        self.libraryRepository = libraryRepository
    }

    var isEmpty: Bool { entries.isEmpty }

    /// Şu an okunan kitaplar; ekranın en üstündeki bölüm.
    var nowReading: [LibraryEntry] {
        entries.filter { $0.readingStatus == .reading }
    }

    /// Durum bölümleri, `ReadingStatus` sırasını koruyarak ve boş olanları eleyerek.
    var entriesByStatus: [(status: ReadingStatus, entries: [LibraryEntry])] {
        let grouped = Dictionary(grouping: entries, by: \.readingStatus)
        return ReadingStatus.allCases.compactMap { status in
            guard let matches = grouped[status], !matches.isEmpty else { return nil }
            return (status, matches)
        }
    }

    var entriesByOwnership: [(status: OwnershipStatus, entries: [LibraryEntry])] {
        let grouped = Dictionary(grouping: entries, by: \.ownershipStatus)
        return OwnershipStatus.allCases.compactMap { status in
            guard let matches = grouped[status], !matches.isEmpty else { return nil }
            return (status, matches)
        }
    }

    /// Bir kitap birden fazla etikete ait olabildiği için gruplama elle yapılır.
    var entriesByCategory: [(category: Models.Category, entries: [LibraryEntry])] {
        var grouped: [Models.Category: [LibraryEntry]] = [:]
        for entry in entries {
            for category in entry.categories {
                grouped[category, default: []].append(entry)
            }
        }
        return grouped
            .map { (category: $0.key, entries: $0.value) }
            .sorted { $0.category.name.localizedCaseInsensitiveCompare($1.category.name) == .orderedAscending }
    }

    func load() {
        do {
            entries = try libraryRepository.fetchEntries()
            self.error = nil
        } catch {
            self.error = UserFacingError(error)
        }
    }

    func delete(_ entry: LibraryEntry) {
        do {
            try libraryRepository.delete(id: entry.id)
            load()
        } catch {
            self.error = UserFacingError(error)
        }
    }
}

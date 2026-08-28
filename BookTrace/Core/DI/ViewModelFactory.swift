//
//  ViewModelFactory.swift
//  DI
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Models
import Observation

/// Navigasyon hedeflerinin ihtiyaç duyduğu view model'ları üretir.
///
/// Destination'lar bir enum case'inden doğduğu için initializer üzerinden
/// bağımlılık alamaz. Bu fabrika environment'a konarak aradaki boşluğu kapatır;
/// Presentation katmanı yine somut servisleri ve DI container'ını görmez.
@MainActor
@Observable
final class ViewModelFactory {
    @ObservationIgnored private let libraryRepository: any LibraryRepository
    @ObservationIgnored private let bookSearching: any BookSearching

    init(libraryRepository: any LibraryRepository, bookSearching: any BookSearching) {
        self.libraryRepository = libraryRepository
        self.bookSearching = bookSearching
    }

    func makeBooksViewModel() -> BooksViewModel {
        BooksViewModel(libraryRepository: libraryRepository)
    }

    func makeExploreViewModel() -> ExploreViewModel {
        ExploreViewModel(bookSearching: bookSearching)
    }

    func makeBookDetailViewModel(book: BookReference) -> BookDetailViewModel {
        BookDetailViewModel(book: book, libraryRepository: libraryRepository)
    }

    func makeLibraryEntryDetailViewModel(entry: LibraryEntry) -> LibraryEntryDetailViewModel {
        LibraryEntryDetailViewModel(entry: entry, libraryRepository: libraryRepository)
    }

    func makeReadingSessionViewModel(entry: LibraryEntry) -> ReadingSessionViewModel {
        ReadingSessionViewModel(entry: entry, libraryRepository: libraryRepository)
    }
}

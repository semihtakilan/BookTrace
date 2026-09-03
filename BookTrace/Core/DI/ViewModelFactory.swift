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
    @ObservationIgnored private let bookDetailFetching: any BookDetailFetching
    @ObservationIgnored private let bookCacheStore: any BookCacheStore
    @ObservationIgnored private let googleBooksBudget: DailyRequestBudget
    @ObservationIgnored private let settings: AppSettings

    init(
        libraryRepository: any LibraryRepository,
        bookSearching: any BookSearching,
        bookDetailFetching: any BookDetailFetching,
        bookCacheStore: any BookCacheStore,
        googleBooksBudget: DailyRequestBudget,
        settings: AppSettings
    ) {
        self.libraryRepository = libraryRepository
        self.bookSearching = bookSearching
        self.bookDetailFetching = bookDetailFetching
        self.bookCacheStore = bookCacheStore
        self.googleBooksBudget = googleBooksBudget
        self.settings = settings
    }

    func makeBooksViewModel() -> BooksViewModel {
        BooksViewModel(libraryRepository: libraryRepository)
    }

    func makeExploreViewModel() -> ExploreViewModel {
        ExploreViewModel(bookSearching: bookSearching)
    }

    func makeProfileViewModel() -> ProfileViewModel {
        ProfileViewModel(libraryRepository: libraryRepository)
    }

    func makeBookDetailViewModel(book: BookReference) -> BookDetailViewModel {
        BookDetailViewModel(
            book: book,
            libraryRepository: libraryRepository,
            bookDetailFetching: bookDetailFetching,
            settings: settings
        )
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            libraryRepository: libraryRepository,
            bookCacheStore: bookCacheStore,
            googleBooksBudget: googleBooksBudget
        )
    }

    func makeLibraryEntryDetailViewModel(entry: LibraryEntry) -> LibraryEntryDetailViewModel {
        LibraryEntryDetailViewModel(entry: entry, libraryRepository: libraryRepository)
    }

    func makeReadingSessionViewModel(entry: LibraryEntry) -> ReadingSessionViewModel {
        ReadingSessionViewModel(entry: entry, libraryRepository: libraryRepository)
    }
}

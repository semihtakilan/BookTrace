//
//  SettingsViewModel.swift
//  Settings
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Foundation
import Models
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var error: UserFacingError?
    private(set) var libraryCount: Int = 0
    /// Bir işlem başarıyla bittiğinde kısa bir onay göstermek için.
    private(set) var confirmation: SettingsConfirmation?

    @ObservationIgnored private let libraryRepository: any LibraryRepository
    @ObservationIgnored private let bookCacheStore: any BookCacheStore
    @ObservationIgnored private let googleBooksBudget: DailyRequestBudget

    /// Bugün Google Books'a giden istek sayısı; yalnızca hata ayıklama
    /// derlemesinde gösteriliyor. Hibrit yönlendirmenin işe yarayıp yaramadığı
    /// tek bir sayıya bakarak anlaşılıyor: gün boyu kullanımda bu sayı tek
    /// haneli kalmalı.
    private(set) var googleRequestsToday = 0

    init(
        libraryRepository: any LibraryRepository,
        bookCacheStore: any BookCacheStore,
        googleBooksBudget: DailyRequestBudget
    ) {
        self.libraryRepository = libraryRepository
        self.bookCacheStore = bookCacheStore
        self.googleBooksBudget = googleBooksBudget
    }

    func loadDiagnostics() async {
        googleRequestsToday = await googleBooksBudget.spentToday()
    }

    var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return [version, build].compactMap { $0 }.joined(separator: " (") + (build == nil ? "" : ")")
    }

    func load() {
        do {
            libraryCount = try libraryRepository.fetchEntries().count
            error = nil
        } catch {
            self.error = UserFacingError(error)
        }
    }

    /// Diskteki arama sonuçlarını siler. Kütüphaneye dokunmaz.
    func clearSearchCache() async {
        await bookCacheStore.removeAll()
        confirmation = .cacheCleared
    }

    func eraseLibrary() {
        do {
            try libraryRepository.deleteAll()
            libraryCount = 0
            confirmation = .libraryErased
        } catch {
            self.error = UserFacingError(error)
        }
    }

    func dismissConfirmation() {
        confirmation = nil
    }
}

enum SettingsConfirmation: Identifiable {
    case cacheCleared
    case libraryErased

    var id: String {
        switch self {
        case .cacheCleared:  "cacheCleared"
        case .libraryErased: "libraryErased"
        }
    }
}

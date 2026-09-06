//
//  LibraryEntryDetailViewModel.swift
//  LibraryDetail
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Foundation
import Models
import Observation

@MainActor
@Observable
final class LibraryEntryDetailViewModel {
    private(set) var entry: LibraryEntry
    private(set) var wasRemoved = false
    var error: UserFacingError?

    @ObservationIgnored
    private let libraryRepository: any LibraryRepository

    init(entry: LibraryEntry, libraryRepository: any LibraryRepository) {
        self.entry = entry
        self.libraryRepository = libraryRepository
    }

    /// Okuma oturumundan dönüldüğünde kayıt tazelensin diye.
    func reload() {
        do {
            if let refreshed = try libraryRepository.entry(for: entry.id) {
                entry = refreshed
                wasRemoved = false
            } else {
                wasRemoved = true
            }
            self.error = nil
        } catch {
            self.error = UserFacingError(error)
        }
    }

    func update(readingStatus: ReadingStatus) {
        var updated = entry
        updated.setReadingStatus(readingStatus)
        persist(updated)
    }

    func update(ownershipStatus: OwnershipStatus) {
        var updated = entry
        updated.ownershipStatus = ownershipStatus
        persist(updated)
    }

    func update(progressType: ProgressType) {
        var updated = entry
        updated.progressType = progressType
        persist(updated)
    }

    func update(currentPage: Int) {
        var updated = entry
        // Kırpma ve durum geçişi `LibraryEntry`'de; buradaki ayrı kural, ilerleme
        // geri alındığında kitabın "Bitirildi" kalmasına yol açıyordu.
        updated.setProgress(currentPage: currentPage)
        persist(updated)
    }

    /// Geçersiz girişler kaydet düğmesini kapatır; sessiz kırpma veya hiçbir
    /// değişiklik yapmadan kapanan bir ilerleme formu kullanıcıyı yanıltır.
    func page(forProgressInput input: String) -> Int? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.allSatisfy({ $0.wholeNumberValue != nil }) else { return nil }
        let digits = trimmed.compactMap(\.wholeNumberValue).map(String.init).joined()
        guard let value = Int(digits) else { return nil }
        switch entry.progressType {
        case .pages:
            if let total = entry.effectivePageCount, value > total { return nil }
            return value
        case .percentage:
            guard value <= 100, let total = entry.effectivePageCount else { return nil }
            if value == 100 { return total }
            return Int((Double(total) * Double(value) / 100).rounded())
        }
    }

    func remove() {
        do {
            try libraryRepository.delete(id: entry.id)
            wasRemoved = true
        } catch {
            self.error = UserFacingError(error)
        }
    }

    private func persist(_ updated: LibraryEntry) {
        do {
            try libraryRepository.update(updated)
            entry = updated
            self.error = nil
        } catch {
            self.error = UserFacingError(error)
        }
    }
}

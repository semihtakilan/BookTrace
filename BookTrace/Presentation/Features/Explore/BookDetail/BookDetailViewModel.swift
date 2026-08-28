//
//  BookDetailViewModel.swift
//  BookDetail
//
//  Created by Semih TAKILAN on 06.08.2026.
//

import Foundation
import Models
import Observation
import SwiftUI

@MainActor
@Observable
final class BookDetailViewModel {
    let book: BookReference

    private(set) var existingEntry: LibraryEntry?
    private(set) var didSave = false
    var isPresentingForm = false
    var error: UserFacingError?

    // MARK: "Add to Library" formunun durumu
    var readingStatus: ReadingStatus = .toRead
    var ownershipStatus: OwnershipStatus = .notOwned
    var progressType: ProgressType = .pages
    var pageCountText: String = ""
    var selectedCategories: [Models.Category] = []
    var newCategoryName: String = ""

    @ObservationIgnored
    private let libraryRepository: any LibraryRepository
    @ObservationIgnored
    private let settings: AppSettings
    @ObservationIgnored
    private var knownCategories: [Models.Category] = []

    init(book: BookReference, libraryRepository: any LibraryRepository, settings: AppSettings) {
        self.book = book
        self.libraryRepository = libraryRepository
        self.settings = settings
    }

    var isInLibrary: Bool { existingEntry != nil }

    var primaryActionTitle: LocalizedStringKey {
        isInLibrary ? "Update Library Details" : "Add to Library"
    }

    /// Hazır etiketler, kitabın kendi konuları ve kullanıcının daha önce
    /// kullandığı etiketler tek listede birleşir.
    var suggestedCategories: [Models.Category] {
        var seen = Set<String>()
        let candidates = selectedCategories
            + knownCategories
            + book.subjects.prefix(4).map { Models.Category(name: $0) }
            + Models.Category.suggested
        return candidates.filter { seen.insert($0.id).inserted }
    }

    var canSave: Bool {
        pageCountText.isEmpty || Int(pageCountText.trimmingCharacters(in: .whitespaces)) != nil
    }

    func load() {
        do {
            existingEntry = try libraryRepository.entry(for: book.id)
            knownCategories = try libraryRepository
                .fetchEntries()
                .flatMap(\.categories)
                .reduce(into: [Models.Category]()) { result, category in
                    if !result.contains(where: { $0.id == category.id }) { result.append(category) }
                }
        } catch {
            self.error = UserFacingError(error)
        }
    }

    /// Formu açar; kitap zaten kütüphanedeyse mevcut seçimlerle doldurur.
    func presentForm() {
        if let entry = existingEntry {
            readingStatus = entry.readingStatus
            ownershipStatus = entry.ownershipStatus
            progressType = entry.progressType
            pageCountText = entry.effectivePageCount.map(String.init) ?? ""
            selectedCategories = entry.categories
        } else {
            // Yeni kitaplar Settings'teki varsayılanlarla açılır.
            readingStatus = settings.defaultReadingStatus
            ownershipStatus = .notOwned
            progressType = settings.defaultProgressType
            pageCountText = book.pageCount.map(String.init) ?? ""
            selectedCategories = []
        }
        newCategoryName = ""
        isPresentingForm = true
    }

    func isSelected(_ category: Models.Category) -> Bool {
        selectedCategories.contains { $0.id == category.id }
    }

    func toggle(_ category: Models.Category) {
        if let index = selectedCategories.firstIndex(where: { $0.id == category.id }) {
            selectedCategories.remove(at: index)
        } else {
            selectedCategories.append(category)
        }
    }

    func addTypedCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let category = Models.Category(name: name)
        if !isSelected(category) { selectedCategories.append(category) }
        newCategoryName = ""
    }

    func save() {
        let pageCount = Int(pageCountText.trimmingCharacters(in: .whitespaces))

        // Mevcut kayıt varsa ilerlemesi ve oturumları korunur; yalnızca
        // kullanıcının bu formdaki seçimleri güncellenir.
        var entry = existingEntry ?? LibraryEntry(book: book)
        entry.book = book
        entry.readingStatus = readingStatus
        entry.ownershipStatus = ownershipStatus
        entry.progressType = progressType
        entry.pageCount = pageCount
        entry.categories = selectedCategories

        do {
            try libraryRepository.add(entry)
            existingEntry = try libraryRepository.entry(for: book.id)
            isPresentingForm = false
            didSave = true
            self.error = nil
        } catch {
            self.error = UserFacingError(error)
        }
    }

    func removeFromLibrary() {
        do {
            try libraryRepository.delete(id: book.id)
            existingEntry = nil
        } catch {
            self.error = UserFacingError(error)
        }
    }
}

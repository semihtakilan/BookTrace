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
    enum DescriptionState: Equatable {
        case idle, loading, available, unavailable, failed
    }

    /// Kitap zenginleşebiliyor: liste kaydında açıklama yok, detay isteği
    /// geldiğinde ekran kendini tamamlıyor.
    private(set) var book: BookReference
    private(set) var descriptionState: DescriptionState = .idle

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
    private let bookDetailFetching: any BookDetailFetching
    @ObservationIgnored
    private let settings: AppSettings
    @ObservationIgnored
    private var knownCategories: [Models.Category] = []
    @ObservationIgnored
    private var formBaseline: LibraryFormSnapshot?
    @ObservationIgnored
    private var formWasEditingExistingEntry = false

    init(
        book: BookReference,
        libraryRepository: any LibraryRepository,
        bookDetailFetching: any BookDetailFetching,
        settings: AppSettings
    ) {
        self.book = book
        self.libraryRepository = libraryRepository
        self.bookDetailFetching = bookDetailFetching
        self.settings = settings
        if hasDescription { descriptionState = .available }
    }

    var isInLibrary: Bool { existingEntry != nil }

    private var hasDescription: Bool {
        !(book.description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

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
        let text = pageCountText.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty || (Int(text).map { $0 > 0 } ?? false)
    }

    /// Sayfa alanının ipucu metni: kaynağın verdiği değer.
    ///
    /// Bu değer alana yazılmaz, yalnızca gösterilir — bkz. `presentForm()`.
    var pageCountPlaceholder: String {
        book.pageCount.map(String.init) ?? "0"
    }

    func load() {
        do {
            existingEntry = try libraryRepository.entry(for: book.id)
            if let existingEntry {
                book = book.merging(existingEntry.book)
                if hasDescription { descriptionState = .available }
            }
            knownCategories = try libraryRepository.fetchCategories()
        } catch {
            self.error = UserFacingError(error)
        }
    }

    /// Kayıtlı metadata önce gösterilir; kütüphanede olsa da eksik açıklama tamamlanır.
    /// İptal edilen ekran isteği, sonradan dönen yanıtla görünümü değiştiremez.
    func enrich() async {
        guard !Task.isCancelled else { return }
        guard !hasDescription else {
            descriptionState = .available
            return
        }
        guard descriptionState != .loading else { return }

        descriptionState = .loading
        do {
            let enriched = try await bookDetailFetching.detail(for: book)
            try Task.checkCancellation()
            book = book.merging(enriched)
            descriptionState = hasDescription ? .available : .unavailable
        } catch {
            if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
                descriptionState = hasDescription ? .available : .idle
            } else {
                descriptionState = .failed
            }
        }
    }

    /// Formu açar; kitap zaten kütüphanedeyse mevcut seçimlerle doldurur.
    ///
    /// Sayfa alanına yalnızca kullanıcının kendi girdiği değer yazılır.
    /// Kaynağın (Google Books) verdiği sayı alana konsaydı, kullanıcı hiçbir
    /// şey yazmadan kaydettiğinde o değer `pageCount`'a kullanıcı girdisi
    /// olarak geçer ve modelin bilinçli olarak koruduğu "kaynaktan gelen" /
    /// "kullanıcının girdiği" ayrımı kaybolurdu. Kaynağın değeri alanın
    /// ipucu (`pageCountPlaceholder`) olarak gösterilir.
    func presentForm() {
        if let entry = existingEntry {
            readingStatus = entry.readingStatus
            ownershipStatus = entry.ownershipStatus
            progressType = entry.progressType
            pageCountText = entry.pageCount.map(String.init) ?? ""
            selectedCategories = entry.categories
        } else {
            // Yeni kitaplar Settings'teki varsayılanlarla açılır.
            readingStatus = settings.defaultReadingStatus
            ownershipStatus = .notOwned
            progressType = settings.defaultProgressType
            pageCountText = ""
            selectedCategories = []
        }
        newCategoryName = ""
        formBaseline = currentFormSnapshot
        formWasEditingExistingEntry = existingEntry != nil
        didSave = false
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
        guard canSave else { return }
        let edited = currentFormSnapshot
        let baseline = formBaseline ?? LibraryFormSnapshot(
            readingStatus: existingEntry?.readingStatus ?? settings.defaultReadingStatus,
            ownershipStatus: existingEntry?.ownershipStatus ?? .notOwned,
            progressType: existingEntry?.progressType ?? settings.defaultProgressType,
            pageCount: existingEntry?.pageCount,
            categories: existingEntry?.categories ?? []
        )

        do {
            // A sheet can stay open while CloudKit or another screen updates the
            // book. Start from the current repository value, not the opening copy.
            let latest = try libraryRepository.entry(for: book.id)
            guard latest != nil || !formWasEditingExistingEntry else {
                self.error = .notInLibrary
                return
            }
            let isNewEntry = latest == nil
            var entry = latest ?? LibraryEntry(book: book)
            if isNewEntry || edited.ownershipStatus != baseline.ownershipStatus {
                entry.ownershipStatus = edited.ownershipStatus
            }
            if isNewEntry || edited.progressType != baseline.progressType {
                entry.progressType = edited.progressType
            }
            // Only an explicit page-count edit can clamp concurrent progress or
            // alter completion; unchanged text must preserve a remote correction.
            if isNewEntry || edited.pageCount != baseline.pageCount {
                entry.setPageCount(edited.pageCount)
            }
            if isNewEntry || edited.readingStatus != baseline.readingStatus {
                entry.setReadingStatus(edited.readingStatus)
            }
            if isNewEntry {
                entry.categories = edited.categories
            } else {
                // Apply category additions/removals as a delta so a remote tag
                // added while the sheet was open survives an unrelated edit.
                let originalIDs = Set(baseline.categories.map(\.id))
                let selectedIDs = Set(edited.categories.map(\.id))
                let removedIDs = originalIDs.subtracting(selectedIDs)
                entry.categories.removeAll { removedIDs.contains($0.id) }
                var retainedIDs = Set(entry.categories.map(\.id))
                entry.categories += edited.categories.filter {
                    !originalIDs.contains($0.id) && retainedIDs.insert($0.id).inserted
                }
            }

            if isNewEntry { try libraryRepository.add(entry) }
            else { try libraryRepository.update(entry) }
            existingEntry = try libraryRepository.entry(for: book.id)
            isPresentingForm = false
            didSave = true
            self.error = nil
        } catch {
            self.error = UserFacingError(error)
        }
    }

    private var currentFormSnapshot: LibraryFormSnapshot {
        LibraryFormSnapshot(
            readingStatus: readingStatus,
            ownershipStatus: ownershipStatus,
            progressType: progressType,
            pageCount: Int(pageCountText.trimmingCharacters(in: .whitespacesAndNewlines)),
            categories: selectedCategories
        )
    }

    private struct LibraryFormSnapshot {
        let readingStatus: ReadingStatus
        let ownershipStatus: OwnershipStatus
        let progressType: ProgressType
        let pageCount: Int?
        let categories: [Models.Category]
    }
}

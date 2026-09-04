//
//  BooksViewModel.swift
//  Books
//
//  Created by Semih TAKILAN on 06.08.2026.
//

import Foundation
import Models
import Observation

/// Kütüphanenin hangi ölçüte göre bölümleneceği.
enum LibraryGrouping: String, CaseIterable, Identifiable, Sendable {
    case all
    case status
    case ownership
    case category

    var id: String { rawValue }
}

enum LibrarySort: String, CaseIterable, Identifiable, Sendable {
    case recentlyAdded
    case title
    case progress

    var id: String { rawValue }
}

/// Bir bölümün başlığını neyin belirlediği.
///
/// Durum ve sahiplik başlıkları çevrilebilir anahtardan gelir; etiket adları
/// kullanıcı verisidir ve olduğu gibi gösterilir. Ayrımı burada tutmak,
/// `LocalizedStringKey`'in (dolayısıyla SwiftUI'ın) view model'a sızmasını önler.
enum LibrarySectionKind: Hashable, Sendable {
    case all
    case status(ReadingStatus)
    case ownership(OwnershipStatus)
    case category(Models.Category)
    case untagged
}

struct LibrarySection: Identifiable, Sendable {
    let kind: LibrarySectionKind
    let entries: [LibraryEntry]

    var id: LibrarySectionKind { kind }
}

@MainActor
@Observable
final class BooksViewModel {
    private(set) var entries: [LibraryEntry] = []

    /// Ekranın en üstündeki "şu an okunan" bölümü.
    private(set) var nowReading: [LibraryEntry] = []
    /// Seçili gruplama ve sıralamaya göre hazırlanmış bölümler.
    private(set) var sections: [LibrarySection] = []

    /// Üst üste okunan gün sayısı ve son bir haftanın günlük özeti.
    private(set) var streakDays = 0
    private(set) var weekActivity: [Bool] = []

    var searchText = "" { didSet { guard searchText != oldValue else { return }; rebuild() } }
    var statusFilter: ReadingStatus? { didSet { guard statusFilter != oldValue else { return }; rebuild() } }
    var grouping: LibraryGrouping = .status { didSet { guard grouping != oldValue else { return }; rebuild() } }
    var sort: LibrarySort = .recentlyAdded { didSet { guard sort != oldValue else { return }; rebuild() } }

    /// Silme onayı bekleyen kayıt. Silme geri alınamadığı için hiçbir yol
    /// onaysız ilerlemez — detay ekranındaki davranışın aynısı.
    var pendingDeletion: LibraryEntry?
    var error: UserFacingError?

    @ObservationIgnored
    private let libraryRepository: any LibraryRepository

    init(libraryRepository: any LibraryRepository) {
        self.libraryRepository = libraryRepository
    }

    var isEmpty: Bool { entries.isEmpty }
    var shelfCount: Int { entries.count - nowReading.count }
    static let shelfStatuses: [ReadingStatus] = [.toRead, .finished, .wishlist, .abandoned]

    /// Kütüphane dolu ama arama hiçbir şey bulmadı.
    var hasNoMatches: Bool { shelfCount > 0 && sections.isEmpty }

    /// Okunan kitaplar kalıcı olarak üstte; arama ve düzenleme aşağıdaki rafa ait.
    var isShowingNowReading: Bool { !nowReading.isEmpty }

    func load(now: Date = Date(), calendar: Calendar = .current) {
        do {
            entries = try libraryRepository.fetchEntries()
            self.error = nil
        } catch {
            self.error = UserFacingError(error)
        }

        // Seri yalnızca kütüphane değiştiğinde hesaplanır; filtre ve sıralama
        // onu etkilemiyor, `rebuild()` içine konsaydı her tuşta tekrarlanırdı.
        let sessions = entries.flatMap(\.readingSessions)
        streakDays = ReadingStreak.current(from: sessions, now: now, calendar: calendar)
        weekActivity = ReadingStreak.recentActivity(from: sessions, now: now, calendar: calendar)

        rebuild()
    }

    // MARK: - Silme

    func requestDeletion(of entry: LibraryEntry) {
        pendingDeletion = entry
    }

    func cancelDeletion() {
        pendingDeletion = nil
    }

    func confirmDeletion() {
        guard let entry = pendingDeletion else { return }
        pendingDeletion = nil
        do {
            try libraryRepository.delete(id: entry.id)
            load()
        } catch {
            self.error = UserFacingError(error)
        }
    }

    // MARK: - Türetme
    //
    // Gruplama ve sıralama `body` içinde değil, veri ya da seçim değiştiğinde
    // bir kez yapılır. `@Observable` computed property'leri önbelleklemediği
    // için bunlar `var { … }` olsaydı her yeniden çizimde — kaydırma sırasında
    // her karede — sözlük kurulup sıralama tekrarlanırdı.

    private func rebuild() {
        nowReading = sorted(entries.filter { $0.readingStatus == .reading })
        sections = makeSections(from: sorted(filtered(entries.filter { $0.readingStatus != .reading })))
    }

    private func filtered(_ entries: [LibraryEntry]) -> [LibraryEntry] {
        let entries = entries.filter { statusFilter == nil || $0.readingStatus == statusFilter }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return entries }

        return entries.filter { entry in
            entry.book.title.localizedStandardContains(query)
                || entry.book.author.localizedStandardContains(query)
                || entry.categories.contains { $0.name.localizedStandardContains(query) }
        }
    }

    /// Eşitlik durumunda başlığa göre çözerek sıralamayı deterministik tutar.
    private func sorted(_ entries: [LibraryEntry]) -> [LibraryEntry] {
        switch sort {
        case .recentlyAdded:
            entries.sorted {
                $0.addedDate == $1.addedDate ? isBefore($0, $1) : $0.addedDate > $1.addedDate
            }
        case .title:
            entries.sorted(by: isBefore)
        case .progress:
            entries.sorted {
                let left = $0.progressFraction ?? -1
                let right = $1.progressFraction ?? -1
                return left == right ? isBefore($0, $1) : left > right
            }
        }
    }

    private func isBefore(_ lhs: LibraryEntry, _ rhs: LibraryEntry) -> Bool {
        let comparison = lhs.book.title.localizedStandardCompare(rhs.book.title)
        return comparison == .orderedSame ? lhs.id < rhs.id : comparison == .orderedAscending
    }

    private func makeSections(from matches: [LibraryEntry]) -> [LibrarySection] {
        guard !matches.isEmpty else { return [] }

        switch grouping {
        case .all:
            return [LibrarySection(kind: .all, entries: matches)]

        case .status:
            let grouped = Dictionary(grouping: matches, by: \.readingStatus)
            return Self.shelfStatuses.compactMap { status in
                guard let entries = grouped[status], !entries.isEmpty else { return nil }
                return LibrarySection(kind: .status(status), entries: entries)
            }

        case .ownership:
            let grouped = Dictionary(grouping: matches, by: \.ownershipStatus)
            return OwnershipStatus.allCases.compactMap { status in
                guard let entries = grouped[status], !entries.isEmpty else { return nil }
                return LibrarySection(kind: .ownership(status), entries: entries)
            }

        case .category:
            // Etikete göre gruplarken bir kitap birden fazla bölümde görünebilir —
            // bu gruplamanın amacı zaten bu. Hiç etiketi olmayanlar da kaybolmasın
            // diye sona ayrı bir bölüme alınır.
            var byCategory: [Models.Category: [LibraryEntry]] = [:]
            var untagged: [LibraryEntry] = []

            for entry in matches {
                if entry.categories.isEmpty {
                    untagged.append(entry)
                } else {
                    for category in entry.categories {
                        byCategory[category, default: []].append(entry)
                    }
                }
            }

            var sections = byCategory
                .map { LibrarySection(kind: .category($0.key), entries: $0.value) }
                .sorted { left, right in
                    guard case .category(let a) = left.kind, case .category(let b) = right.kind else {
                        return false
                    }
                    return a.name.localizedStandardCompare(b.name) == .orderedAscending
                }

            if !untagged.isEmpty {
                sections.append(LibrarySection(kind: .untagged, entries: untagged))
            }
            return sections
        }
    }
}

//
//  LibraryEntry.swift
//  Models
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Foundation

/// Kullanıcının kütüphanesindeki bir kitap: uzak kitabın kendisi (`BookReference`)
/// artı yalnızca bu kullanıcıya ait okuma durumu.
///
/// `id`, kaynaklandığı `BookReference.id` ile aynıdır; aynı kitabın iki kez
/// eklenmesini engellemek için kullanılır.
public struct LibraryEntry: Identifiable, Hashable, Sendable, Codable {
    public var book: BookReference
    public var readingStatus: ReadingStatus
    public var ownershipStatus: OwnershipStatus
    public var progressType: ProgressType
    /// Kullanıcının girdiği sayfa sayısı; boşsa kaynağın verdiği değer kullanılır.
    public var pageCount: Int?
    /// İlerleme her zaman sayfa cinsindendir — `progressType` yalnızca gösterimi değiştirir.
    public var currentPage: Int
    public var categories: [Category]
    public var addedDate: Date
    public var readingSessions: [ReadingSession]

    public var id: String { book.id }

    public init(
        book: BookReference,
        readingStatus: ReadingStatus = .toRead,
        ownershipStatus: OwnershipStatus = .notOwned,
        progressType: ProgressType = .pages,
        pageCount: Int? = nil,
        currentPage: Int = 0,
        categories: [Category] = [],
        addedDate: Date = Date(),
        readingSessions: [ReadingSession] = []
    ) {
        self.book = book
        self.readingStatus = readingStatus
        self.ownershipStatus = ownershipStatus
        self.progressType = progressType
        self.pageCount = pageCount
        self.currentPage = max(0, currentPage)
        self.categories = categories
        self.addedDate = addedDate
        self.readingSessions = readingSessions
    }

    // MARK: - Türetilmiş ilerleme

    /// Kullanıcının girdiği sayfa sayısı önceliklidir; yoksa kaynağınki.
    public var effectivePageCount: Int? {
        if let pageCount, pageCount > 0 { return pageCount }
        if let sourceCount = book.pageCount, sourceCount > 0 { return sourceCount }
        return nil
    }

    /// 0...1 aralığında ilerleme. Sayfa sayısı bilinmiyorsa `nil`.
    public var progressFraction: Double? {
        guard let total = effectivePageCount, total > 0 else { return nil }
        return min(1, max(0, Double(currentPage) / Double(total)))
    }

    public var progressPercentage: Int? {
        progressFraction.map { Int(($0 * 100).rounded()) }
    }

    public var remainingPages: Int? {
        guard let total = effectivePageCount else { return nil }
        return max(0, total - currentPage)
    }

    public var totalPagesRead: Int {
        readingSessions.reduce(0) { $0 + $1.pagesRead }
    }

    public var totalReadSeconds: Int {
        readingSessions.reduce(0) { $0 + $1.durationSeconds }
    }

    /// Bu kitap için sayfa başına ölçülen süre; oturum yoksa varsayılana düşer.
    public var secondsPerPage: TimeInterval {
        ReadingSpeedEstimator.secondsPerPage(for: readingSessions)
    }

    /// Kitabı bitirmek için kalan tahmini süre. Sayfa sayısı yoksa veya kitap
    /// bittiyse `nil`.
    public var estimatedRemainingSeconds: TimeInterval? {
        ReadingSpeedEstimator.estimatedRemainingSeconds(for: self)
    }

    /// Tahminin gerçek oturumlardan mı yoksa varsayılan hızdan mı geldiği.
    public var hasPersonalizedSpeed: Bool {
        ReadingSpeedEstimator.hasPersonalizedSpeed(for: readingSessions)
    }

    // MARK: - Mutasyonlar

    /// Yeni bir oturumu ekler ve `currentPage`'i ilerletir.
    public mutating func apply(_ session: ReadingSession) {
        readingSessions.append(session)
        advanceProgress(by: session.pagesRead)
    }

    /// İlerlemeyi sayfa sayısını aşmayacak biçimde artırır ve gerekirse durumu günceller.
    public mutating func advanceProgress(by pages: Int) {
        let updated = currentPage + max(0, pages)
        currentPage = effectivePageCount.map { min(updated, $0) } ?? updated

        if readingStatus == .toRead || readingStatus == .wishlist {
            readingStatus = .reading
        }
        if let total = effectivePageCount, currentPage >= total {
            readingStatus = .finished
        }
    }
}

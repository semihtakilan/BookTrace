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
    public var readingStatus: ReadingStatus {
        didSet {
            if readingStatus != .finished {
                finishedDate = nil
            } else if oldValue != .finished {
                finishedDate = Date()
            }
        }
    }
    public var ownershipStatus: OwnershipStatus
    public var progressType: ProgressType
    /// Kullanıcının girdiği sayfa sayısı; boşsa kaynağın verdiği değer kullanılır.
    public var pageCount: Int?
    /// İlerleme her zaman sayfa cinsindendir — `progressType` yalnızca gösterimi değiştirir.
    public var currentPage: Int
    public var categories: [Category]
    public var addedDate: Date
    public var readingSessions: [ReadingSession]
    /// Invalid ratings are treated as unrated, including values from imports.
    public var rating: Int? {
        didSet { rating = rating.flatMap { (1...5).contains($0) ? $0 : nil } }
    }
    public var finishedDate: Date?
    public var notes: String?
    public var isFavorite: Bool
    public var quotes: [Quote]

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
        readingSessions: [ReadingSession] = [],
        rating: Int? = nil,
        finishedDate: Date? = nil,
        notes: String? = nil,
        isFavorite: Bool = false,
        quotes: [Quote] = []
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
        self.rating = rating.flatMap { (1...5).contains($0) ? $0 : nil }
        // A missing historical finish date remains unknown; transitions below
        // record the date without inventing one when restoring a legacy entry.
        self.finishedDate = readingStatus == .finished ? finishedDate : nil
        self.notes = notes
        self.isFavorite = isFavorite
        self.quotes = quotes
        // Eski kayıtlarda da "bitmiş" durumunu bilinen son sayfayla eşleştir.
        if readingStatus == .finished, let total = effectivePageCount {
            self.currentPage = total
        }
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

    /// Bitmiş olarak işaretlemek ilerlemeyi tamamlar; ölçülmemiş bir okuma
    /// oturumu üretmez. Sayfa sayısı bilinmiyorsa kullanıcının durumu korunur.
    public mutating func setReadingStatus(_ status: ReadingStatus, at date: Date = Date()) {
        let wasFinished = readingStatus == .finished
        readingStatus = status
        if status == .finished, !wasFinished { finishedDate = date }
        if status == .finished, let total = effectivePageCount {
            currentPage = total
        }
    }

    /// İlerlemenin tek giriş noktası.
    ///
    /// İlerleme ve okuma durumu birbirine bağlı: sayfa sayfaya taşınırsa kitap
    /// biter, geri alınırsa bitmiş sayılamaz. Bu kural daha önce üç ayrı yerde
    /// (form, elle güncelleme, okuma oturumu) farklı biçimlerde uygulandığı için
    /// kayıtlar tutarsız hâle gelebiliyordu; artık tek yer burası.
    public mutating func setProgress(currentPage newValue: Int, at date: Date = Date()) {
        currentPage = clampedPage(newValue)
        reconcileStatus(at: date)
    }

    /// Sayfa sayısını değiştirir ve ilerlemeyi yeni tavana göre yeniden kırpar.
    ///
    /// Sayfa sayısı düşürüldüğünde ilerleme olduğu gibi kalırsa "716 / 100 sayfa"
    /// gibi imkânsız değerler çıkıyordu.
    public mutating func setPageCount(_ newValue: Int?) {
        pageCount = newValue
        if readingStatus == .finished {
            setReadingStatus(.finished)
        } else {
            setProgress(currentPage: currentPage)
        }
    }

    /// Yeni bir oturumu ekler ve `currentPage`'i ilerletir.
    ///
    /// Oturumun sayfa sayısı kalan sayfayla sınırlanır: `pagesRead` okuma hızı
    /// hesabının paydası, kalanı aşan tek bir giriş kütüphanenin tamamındaki
    /// tahminleri kalıcı olarak bozuyordu.
    public mutating func apply(_ session: ReadingSession) {
        let allowedPages = remainingPages.map { min(session.pagesRead, $0) } ?? session.pagesRead
        readingSessions.append(
            ReadingSession(
                id: session.id,
                startDate: session.startDate,
                durationSeconds: session.durationSeconds,
                pagesRead: allowedPages
            )
        )
        setProgress(currentPage: currentPage + allowedPages, at: session.endDate)
    }

    /// İlerlemeyi sayfa sayısını aşmayacak biçimde artırır ve gerekirse durumu günceller.
    public mutating func advanceProgress(by pages: Int) {
        setProgress(currentPage: currentPage + max(0, pages))
    }

    private func clampedPage(_ page: Int) -> Int {
        let flooredPage = max(0, page)
        return effectivePageCount.map { min(flooredPage, $0) } ?? flooredPage
    }

    /// Okuma durumunu ilerlemeyle uyumlu hâle getirir.
    ///
    /// `.abandoned` ve `.wishlist` gibi kullanıcının bilinçli seçimleri, ilerleme
    /// başlamadıkça korunur.
    private mutating func reconcileStatus(at date: Date) {
        guard let total = effectivePageCount, total > 0 else {
            if currentPage > 0, readingStatus == .toRead || readingStatus == .wishlist {
                readingStatus = .reading
            }
            return
        }

        if currentPage >= total {
            setReadingStatus(.finished, at: date)
        } else if readingStatus == .finished {
            // İlerleme geri alındıysa kitap artık bitmiş değil.
            readingStatus = .reading
        } else if currentPage > 0, readingStatus == .toRead || readingStatus == .wishlist {
            readingStatus = .reading
        }
    }

    // New optional/defaulted fields must not invalidate backups from V1.
    private enum CodingKeys: String, CodingKey {
        case book, readingStatus, ownershipStatus, progressType, pageCount, currentPage
        case categories, addedDate, readingSessions, rating, finishedDate, notes, isFavorite, quotes
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            book: try values.decode(BookReference.self, forKey: .book),
            readingStatus: try values.decodeIfPresent(ReadingStatus.self, forKey: .readingStatus) ?? .toRead,
            ownershipStatus: try values.decodeIfPresent(OwnershipStatus.self, forKey: .ownershipStatus) ?? .notOwned,
            progressType: try values.decodeIfPresent(ProgressType.self, forKey: .progressType) ?? .pages,
            pageCount: try values.decodeIfPresent(Int.self, forKey: .pageCount),
            currentPage: try values.decodeIfPresent(Int.self, forKey: .currentPage) ?? 0,
            categories: try values.decodeIfPresent([Category].self, forKey: .categories) ?? [],
            addedDate: try values.decode(Date.self, forKey: .addedDate),
            readingSessions: try values.decodeIfPresent([ReadingSession].self, forKey: .readingSessions) ?? [],
            rating: try values.decodeIfPresent(Int.self, forKey: .rating),
            finishedDate: try values.decodeIfPresent(Date.self, forKey: .finishedDate),
            notes: try values.decodeIfPresent(String.self, forKey: .notes),
            isFavorite: try values.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false,
            quotes: try values.decodeIfPresent([Quote].self, forKey: .quotes) ?? []
        )
    }
}

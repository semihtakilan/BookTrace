//
//  ReadingSessionViewModel.swift
//  ReadingMode
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Foundation
import Models
import Observation
import SwiftUI

@MainActor
@Observable
final class ReadingSessionViewModel {
    private(set) var entry: LibraryEntry
    private(set) var elapsedSeconds = 0
    private(set) var isRunning = false
    private(set) var didSave = false

    var isFinishing = false
    var pagesReadText = ""
    var error: UserFacingError?

    /// Oturum sırasında yeni geçilen süre dönüm noktası (dakika). Ekran bunu
    /// görüp kısa bir bildirim gösterir ve `clearMilestone()` ile temizler.
    private(set) var reachedMilestone: Int?

    /// Kayıt sonrası kutlanacak bir şey varsa. `nil` ise ekran sessizce kapanır.
    private(set) var outcome: SessionOutcome?

    @ObservationIgnored
    private let libraryRepository: any LibraryRepository

    /// Süre `Timer` sayarak değil, gerçek tarihlerden hesaplanır. Uygulama arka
    /// plana atıldığında tikler dursa bile geri dönüldüğünde geçen süre doğru kalır.
    @ObservationIgnored private var sessionStartDate = Date()
    @ObservationIgnored private var accumulatedSeconds: TimeInterval = 0
    @ObservationIgnored private var runningSince: Date?

    /// Kutlanmış en yüksek dakika. Uygulama arka planda uzun süre kaldığında
    /// sayaç bir anda sıçrıyor; aradaki bütün dönüm noktaları için üst üste
    /// bildirim göstermek yerine yalnızca sonuncusu gösterilir.
    @ObservationIgnored private var highestMilestone = 0
    @ObservationIgnored private static let milestoneMinutes = [5, 10, 15, 20, 30, 45, 60, 90, 120]

    init(entry: LibraryEntry, libraryRepository: any LibraryRepository) {
        self.entry = entry
        self.libraryRepository = libraryRepository
    }

    var bookTitle: String { entry.book.title }

    /// Finish ekranında gösterilen ayrıntılı süre (`01:06` gibi).
    var elapsedDisplay: String { DurationFormatter.timer(seconds: elapsedSeconds) }

    var pagesReadValue: Int? {
        Int(pagesReadText.trimmingCharacters(in: .whitespaces))
    }

    /// Bu oturumda kaydedilebilecek en fazla sayfa; kitabın kalanı.
    var maximumPages: Int? { entry.remainingPages }

    var canSave: Bool {
        guard let pages = pagesReadValue, pages >= 0, elapsedSeconds > 0 else { return false }
        guard let maximumPages else { return true }
        return pages <= maximumPages
    }

    /// Save neden pasif — girilen değer kitabın kalanını aşıyorsa açıklar.
    var pagesLimitMessage: LocalizedStringKey? {
        guard let pages = pagesReadValue, let maximumPages, pages > maximumPages else { return nil }
        return "This book only has \(maximumPages) pages left."
    }

    /// Kaydedilecek oturumun kitabı nereye taşıyacağının önizlemesi.
    var projectedPage: Int? {
        guard let pages = pagesReadValue else { return nil }
        var preview = entry
        preview.advanceProgress(by: pages)
        return preview.currentPage
    }

    func start() {
        guard runningSince == nil, accumulatedSeconds == 0 else { return }
        sessionStartDate = Date()
        runningSince = sessionStartDate
        isRunning = true
        tick()
    }

    /// Ekran her göründüğünde ve saniyede bir çağrılır; yalnızca görüntüyü tazeler.
    func tick() {
        elapsedSeconds = Int(currentElapsed.rounded(.down))
        noteMilestone()
    }

    func clearMilestone() {
        reachedMilestone = nil
    }

    private func noteMilestone() {
        guard let crossed = Self.milestone(atElapsed: elapsedSeconds, after: highestMilestone) else { return }
        highestMilestone = crossed
        reachedMilestone = crossed
    }

    /// Geçilen en yüksek süre eşiği; daha önce duyurulmuş olandan büyük değilse `nil`.
    ///
    /// Saf ve durumsuz olduğu için sayaç işletmeden test edilebiliyor.
    static func milestone(atElapsed seconds: Int, after announced: Int) -> Int? {
        let minutes = seconds / 60
        guard let crossed = milestoneMinutes.last(where: { $0 <= minutes }),
              crossed > announced else { return nil }
        return crossed
    }

    func togglePause() {
        if let runningSince {
            accumulatedSeconds += Date().timeIntervalSince(runningSince)
            self.runningSince = nil
            isRunning = false
        } else {
            runningSince = Date()
            isRunning = true
        }
        tick()
    }

    /// Finish ekranına geçerken sayaç durur; kullanıcı geri dönerse kaldığı yerden devam eder.
    func beginFinishing() {
        if runningSince != nil { togglePause() }
        pagesReadText = ""
        isFinishing = true
    }

    /// Finish ekranı kaydedilmeden kapandığında sayaç kaldığı yerden devam eder.
    func resumeAfterFinishing() {
        guard !didSave, runningSince == nil else { return }
        togglePause()
    }

    /// Oturumu kaydeder: süre ve sayfa yazılır, `currentPage` ve okuma durumu güncellenir.
    func save() {
        guard let pages = pagesReadValue else { return }

        let session = ReadingSession(
            startDate: sessionStartDate,
            durationSeconds: elapsedSeconds,
            pagesRead: pages
        )

        let fractionBefore = entry.progressFraction ?? 0

        do {
            entry = try libraryRepository.appendSession(session, toEntryWith: entry.id)
            isFinishing = false
            outcome = SessionOutcome(fractionBefore: fractionBefore, entry: entry, pagesRead: pages)
            didSave = true
        } catch {
            self.error = UserFacingError(error)
        }
    }

    /// Kutlama görüldü; okuma ekranı artık kapanabilir.
    func acknowledgeOutcome() {
        outcome = nil
    }

    /// Oturum kaydedildi ve kutlanacak bir şey kalmadı.
    ///
    /// `didSave` tek başına yetmiyor: kayıt anında kutlama da başlıyor ve ekran
    /// hemen kapanırsa kullanıcı onu hiç görmüyor.
    var isReadyToDismiss: Bool { didSave && outcome == nil }

    private var currentElapsed: TimeInterval {
        accumulatedSeconds + (runningSince.map { Date().timeIntervalSince($0) } ?? 0)
    }
}

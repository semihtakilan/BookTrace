//
//  ReadingSessionViewModel.swift
//  ReadingMode
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Foundation
import BookTraceShared
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
    private(set) var didDiscard = false

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
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let isProProvider: @MainActor () -> Bool
    @ObservationIgnored private let liveActivity: any ReadingLiveActivityControlling
    @ObservationIgnored private var hasLiveActivity = false

    /// Süre `Timer` sayarak değil, gerçek tarihlerden hesaplanır. Uygulama arka
    /// plana atıldığında tikler dursa bile geri dönüldüğünde geçen süre doğru kalır.
    @ObservationIgnored private var sessionStartDate = Date()
    @ObservationIgnored private var accumulatedSeconds: TimeInterval = 0
    @ObservationIgnored private var runningSince: Date?
    @ObservationIgnored private var hasStarted = false
    @ObservationIgnored private var shouldResumeAfterFinishing = false

    /// Kutlanmış en yüksek dakika. Uygulama arka planda uzun süre kaldığında
    /// sayaç bir anda sıçrıyor; aradaki bütün dönüm noktaları için üst üste
    /// bildirim göstermek yerine yalnızca sonuncusu gösterilir.
    @ObservationIgnored private var highestMilestone = 0
    @ObservationIgnored private static let milestoneMinutes = [5, 10, 15, 20, 30, 45, 60, 90, 120]

    init(
        entry: LibraryEntry,
        libraryRepository: any LibraryRepository,
        now: @escaping () -> Date = Date.init,
        isProProvider: @escaping @MainActor () -> Bool = { false },
        liveActivity: (any ReadingLiveActivityControlling)? = nil
    ) {
        self.entry = entry
        self.libraryRepository = libraryRepository
        self.now = now
        self.isProProvider = isProProvider
        self.liveActivity = liveActivity ?? ReadingLiveActivityController()
    }

    var bookTitle: String { entry.book.title }

    /// Finish ekranında gösterilen ayrıntılı süre (`01:06` gibi).
    var elapsedDisplay: String { DurationFormatter.timer(seconds: elapsedSeconds) }

    var pagesReadValue: Int? {
        let normalized = pagesReadText.trimmingCharacters(in: .whitespacesAndNewlines)
            .map { character in character.wholeNumberValue.map(String.init) ?? String(character) }
            .joined()
        return Int(normalized)
    }

    /// Bu oturumda kaydedilebilecek en fazla sayfa; kitabın kalanı.
    var maximumPages: Int? { entry.remainingPages }

    var canSave: Bool {
        guard !didSave, !didDiscard, let pages = pagesReadValue, pages >= 0,
              pages <= Int.max - entry.currentPage, elapsedSeconds > 0 else { return false }
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
        guard let pages = pagesReadValue, pages >= 0, pages <= Int.max - entry.currentPage else { return nil }
        var preview = entry
        preview.advanceProgress(by: pages)
        return preview.currentPage
    }

    func start(palette: BookPalette? = nil) {
        guard !hasStarted, !didSave, !didDiscard else { return }
        hasStarted = true
        sessionStartDate = now()
        runningSince = sessionStartDate
        isRunning = true
        tick()
        if isProProvider() {
            liveActivity.start(entry: entry, palette: palette ?? .fallback(for: entry.id), clock: activityClock)
            hasLiveActivity = true
        }
    }

    /// Ekran her göründüğünde ve saniyede bir çağrılır; yalnızca görüntüyü tazeler.
    func tick() {
        elapsedSeconds = Int(currentElapsed.rounded(.down))
        noteMilestone()
        if hasLiveActivity, !isProProvider() {
            liveActivity.end()
            hasLiveActivity = false
        }
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
        guard hasStarted, !didSave, !didDiscard, !isFinishing else { return }
        if let runningSince {
            accumulatedSeconds += max(0, now().timeIntervalSince(runningSince))
            self.runningSince = nil
            isRunning = false
        } else {
            runningSince = now()
            isRunning = true
        }
        tick()
        updateLiveActivity()
    }

    /// Finish ekranına geçerken sayaç durur; kullanıcı geri dönerse kaldığı yerden devam eder.
    func beginFinishing() {
        guard !isFinishing, !didSave, !didDiscard else { return }
        shouldResumeAfterFinishing = isRunning
        if runningSince != nil { togglePause() }
        isFinishing = true
    }

    /// Finish ekranı kaydedilmeden kapandığında sayaç kaldığı yerden devam eder.
    func resumeAfterFinishing() {
        guard !didSave, !didDiscard, !isFinishing else { return }
        if shouldResumeAfterFinishing, runningSince == nil { togglePause() }
        shouldResumeAfterFinishing = false
    }

    func discard() {
        if let runningSince {
            accumulatedSeconds += max(0, now().timeIntervalSince(runningSince))
            self.runningSince = nil
        }
        isRunning = false
        didDiscard = true
        isFinishing = false
        liveActivity.end()
        hasLiveActivity = false
    }

    /// Oturumu kaydeder: süre ve sayfa yazılır, `currentPage` ve okuma durumu güncellenir.
    func save() {
        tick()
        guard canSave, let pages = pagesReadValue else { return }

        // A caller may save without first opening the finish screen. Freeze
        // the measured duration here too, and never append a second session.
        if let runningSince {
            accumulatedSeconds += max(0, now().timeIntervalSince(runningSince))
            self.runningSince = nil
            isRunning = false
        }

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
            liveActivity.end()
            hasLiveActivity = false
        } catch {
            self.error = UserFacingError(error)
            updateLiveActivity()
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
    var isReadyToDismiss: Bool { didDiscard || (didSave && outcome == nil) }

    private var currentElapsed: TimeInterval {
        accumulatedSeconds + (runningSince.map { max(0, now().timeIntervalSince($0)) } ?? 0)
    }

    private var activityClock: ReadingActivityClock {
        ReadingActivityClock(accumulatedSeconds: accumulatedSeconds, runningSince: runningSince, now: now())
    }

    private func updateLiveActivity() {
        guard isProProvider() else { liveActivity.end(); return }
        liveActivity.update(clock: activityClock, currentPage: entry.currentPage, pageCount: entry.effectivePageCount)
    }
}

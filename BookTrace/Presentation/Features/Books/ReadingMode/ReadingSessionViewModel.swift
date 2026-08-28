//
//  ReadingSessionViewModel.swift
//  ReadingMode
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Foundation
import Models
import Observation

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

    @ObservationIgnored
    private let libraryRepository: any LibraryRepository

    /// Süre `Timer` sayarak değil, gerçek tarihlerden hesaplanır. Uygulama arka
    /// plana atıldığında tikler dursa bile geri dönüldüğünde geçen süre doğru kalır.
    @ObservationIgnored private var sessionStartDate = Date()
    @ObservationIgnored private var accumulatedSeconds: TimeInterval = 0
    @ObservationIgnored private var runningSince: Date?

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

    var canSave: Bool {
        guard let pages = pagesReadValue else { return false }
        return pages >= 0 && elapsedSeconds > 0
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

        do {
            entry = try libraryRepository.appendSession(session, toEntryWith: entry.id)
            isFinishing = false
            didSave = true
        } catch {
            self.error = UserFacingError(error)
        }
    }

    private var currentElapsed: TimeInterval {
        accumulatedSeconds + (runningSince.map { Date().timeIntervalSince($0) } ?? 0)
    }
}

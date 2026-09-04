//
//  SessionOutcome.swift
//  ReadingMode
//
//  Created by Semih TAKILAN on 04.09.2026.
//

import Models
import SwiftUI

/// Kaydedilen bir oturumun kutlanmaya değer sonucu.
///
/// Her oturum kutlanmaz: on beş dakikada üç sayfa okumak da kaydedilir ama
/// ekranı kapatıp yola devam etmek gerekir. Kutlama yalnızca gerçekten bir eşik
/// geçildiğinde çıkar — aksi hâlde birkaç oturum sonra görünmez oluyor.
enum SessionOutcome: Equatable, Sendable {
    /// Kitap bitti.
    case finishedBook
    /// Yüzde 25, 50 ya da 75 çizgisi bu oturumda geçildi.
    case milestone(percent: Int)
    /// Bu kitabın ilk kaydedilmiş oturumu.
    case firstSession

    private static let thresholds = [75, 50, 25]

    /// Kayıttan önceki ve sonraki duruma bakarak sonucu belirler.
    init?(fractionBefore: Double, entry: LibraryEntry, pagesRead: Int) {
        if entry.readingStatus == .finished {
            self = .finishedBook
            return
        }

        let before = Int((fractionBefore * 100).rounded(.down))
        let after = entry.progressPercentage ?? before

        if let crossed = Self.thresholds.first(where: { $0 > before && after >= $0 }) {
            self = .milestone(percent: crossed)
            return
        }

        // İlk oturum ancak gerçekten okunduysa kutlanır; sıfır sayfalık bir
        // zaman kaydı bir başlangıç sayılmaz.
        if entry.readingSessions.count == 1, pagesRead > 0 {
            self = .firstSession
            return
        }

        return nil
    }

    var title: LocalizedStringKey {
        switch self {
        case .finishedBook:              "You finished it."
        case .milestone(let percent):    percent >= 75 ? "Almost there." : (percent >= 50 ? "Halfway." : "You’re in.")
        case .firstSession:              "That’s a start."
        }
    }

    var message: LocalizedStringKey {
        switch self {
        case .finishedBook:           "One more book that is yours for good."
        case .milestone(let percent): "\(percent)% of this book is behind you."
        case .firstSession:           "Your pace is being measured now. The next estimate will be yours."
        }
    }

    var systemImage: String {
        switch self {
        case .finishedBook: "checkmark.seal.fill"
        case .milestone:    "bookmark.fill"
        case .firstSession: "sparkles"
        }
    }

    /// Kitap bitirmek diğerlerinden büyük bir olay; kutlama da öyle olsun.
    var isMajor: Bool { self == .finishedBook }
}

/// Oturum sırasında geçilen süre eşiği için gösterilen tek satır.
enum SessionMilestoneCopy {
    static func message(minutes: Int) -> LocalizedStringKey {
        switch minutes {
        case ..<10: "Five minutes in. The room is quiet."
        case ..<20: "\(minutes) minutes. You’ve settled in."
        case ..<45: "\(minutes) minutes. This is a real sitting."
        default:    "\(minutes) minutes. The world can wait."
        }
    }
}

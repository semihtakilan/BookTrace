//
//  ModelTitles.swift
//  Shared
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Models
import SwiftUI

/// Domain enum'larının çevrilebilir ekran adları.
///
/// `Models` paketi SwiftUI'dan bağımsız kalsın diye `LocalizedStringKey`
/// karşılıkları burada, Presentation katmanında tanımlı.
extension ReadingStatus {
    var titleKey: LocalizedStringKey {
        switch self {
        case .wishlist:  "Wishlist"
        case .toRead:    "To Read"
        case .reading:   "Reading"
        case .finished:  "Finished"
        case .abandoned: "Abandoned"
        }
    }
}

extension OwnershipStatus {
    var titleKey: LocalizedStringKey {
        switch self {
        case .borrowed: "Borrowed"
        case .notOwned: "Not Owned"
        case .owned:    "Owned"
        }
    }
}

extension ProgressType {
    var titleKey: LocalizedStringKey {
        switch self {
        case .pages:      "Pages"
        case .percentage: "Percentage"
        }
    }
}

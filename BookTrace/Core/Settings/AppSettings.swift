//
//  AppSettings.swift
//  Settings
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Foundation
import Models
import Observation
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// `nil`, SwiftUI'a "cihazın ayarını kullan" demektir.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light:  "Light"
        case .dark:   "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "iphone"
        case .light:  "sun.max"
        case .dark:   "moon"
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english = "en"
    case turkish = "tr"
    case german  = "de"

    var id: String { rawValue }

    /// `nil` ise cihazın dili kullanılır.
    var locale: Locale? {
        self == .system ? nil : Locale(identifier: rawValue)
    }

    /// Dil adları çevrilmez; her dil kendi adıyla yazılır. Kullanıcı anlamadığı
    /// bir dile düştüğünde geri dönebilmek için kendi dilini tanıyabilmeli.
    var title: String {
        switch self {
        case .system:  "System"
        case .english: "English"
        case .turkish: "Türkçe"
        case .german:  "Deutsch"
        }
    }
}

/// Kullanıcının uygulama tercihleri. `UserDefaults`'ta saklanır.
@MainActor
@Observable
final class AppSettings {
    var theme: AppTheme {
        didSet { defaults.set(theme.rawValue, forKey: Key.theme) }
    }

    var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Key.language) }
    }

    /// "Add to Library" formu bu değerlerle açılır.
    var defaultReadingStatus: ReadingStatus {
        didSet { defaults.set(defaultReadingStatus.rawValue, forKey: Key.defaultReadingStatus) }
    }

    var defaultProgressType: ProgressType {
        didSet { defaults.set(defaultProgressType.rawValue, forKey: Key.defaultProgressType) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    private enum Key {
        static let theme = "settings.theme"
        static let language = "settings.language"
        static let defaultReadingStatus = "settings.defaultReadingStatus"
        static let defaultProgressType = "settings.defaultProgressType"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = defaults.string(forKey: Key.theme).flatMap(AppTheme.init) ?? .system
        language = defaults.string(forKey: Key.language).flatMap(AppLanguage.init) ?? .system
        defaultReadingStatus = defaults.string(forKey: Key.defaultReadingStatus)
            .flatMap(ReadingStatus.init) ?? .toRead
        defaultProgressType = defaults.string(forKey: Key.defaultProgressType)
            .flatMap(ProgressType.init) ?? .pages
    }

    /// Ekranlara verilecek yerel ayar. Dil "System" iken cihazınki kullanılır.
    var resolvedLocale: Locale {
        language.locale ?? Locale.autoupdatingCurrent
    }
}

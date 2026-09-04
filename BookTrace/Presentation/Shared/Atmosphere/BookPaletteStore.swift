//
//  BookPaletteStore.swift
//  Atmosphere
//
//  Created by Semih TAKILAN on 04.09.2026.
//

import Kingfisher
import Models
import Observation
import SwiftUI

/// Kapaklardan çıkarılan renkleri tutar ve tekrar tekrar çıkarılmasını önler.
///
/// Sonuçlar diske de yazılır: kapak görseli Kingfisher önbelleğinde olsa bile
/// yeniden çözümlemek bir kare sürüyor ve kütüphane açılırken bütün kartların
/// rengi gözle görülür biçimde "sonradan" oturuyordu. Kayıtlı tohumla renk ilk
/// karede doğru geliyor.
@MainActor
@Observable
final class BookPaletteStore {
    private var palettes: [String: BookPalette]

    @ObservationIgnored private var resolving: Set<String> = []
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private static let storageKey = "palette.covers"
    /// Kütüphane büyüdükçe sözlük sınırsız büyümesin.
    @ObservationIgnored private static let storageLimit = 400

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.palettes = Self.loadStored(from: defaults)
    }

    /// Bilinen renk; yoksa kitabın kimliğinden türeyen sabit yedek.
    func palette(for book: BookReference) -> BookPalette {
        palettes[book.id] ?? .fallback(for: book.id)
    }

    /// Kapağı indirir (önbellekteyse oradan alır) ve rengini çıkarır.
    ///
    /// Aynı kitap için ikinci bir çağrı iş yapmaz; ekranda aynı kitabın birden
    /// çok kartı olduğunda (raf + arama sonucu) aksi hâlde aynı görsel birkaç
    /// kez çözümleniyordu.
    func resolve(for book: BookReference) async {
        guard palettes[book.id] == nil, !resolving.contains(book.id) else { return }
        guard let url = book.coverURL else { return }

        resolving.insert(book.id)
        defer { resolving.remove(book.id) }

        guard let result = try? await KingfisherManager.shared.retrieveImage(with: url),
              let palette = BookPaletteExtractor.palette(from: result.image) else { return }

        palettes[book.id] = palette
        persist()
    }

    private func persist() {
        // Sona eklenenler kalır: en son bakılan kitaplar en olası tekrar.
        var stored = palettes
        if stored.count > Self.storageLimit {
            stored = Dictionary(uniqueKeysWithValues: stored.suffix(Self.storageLimit))
        }
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func loadStored(from defaults: UserDefaults) -> [String: BookPalette] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: BookPalette].self, from: data) else { return [:] }
        return decoded
    }
}

// MARK: - Ortam üzerinden dağıtım

private struct BookPaletteEnvironmentKey: EnvironmentKey {
    static let defaultValue = BookPalette.neutral
}

private struct BookAmbienceEnvironmentKey: EnvironmentKey {
    static let defaultValue = BookAmbience.literary
}

extension EnvironmentValues {
    /// O anda gösterilen kitabın rengi. Alt görünümler kitabı taşımadan okur.
    var bookPalette: BookPalette {
        get { self[BookPaletteEnvironmentKey.self] }
        set { self[BookPaletteEnvironmentKey.self] = newValue }
    }

    var bookAmbience: BookAmbience {
        get { self[BookAmbienceEnvironmentKey.self] }
        set { self[BookAmbienceEnvironmentKey.self] = newValue }
    }
}

private struct BookAtmosphereModifier: ViewModifier {
    let book: BookReference
    @Environment(BookPaletteStore.self) private var store

    func body(content: Content) -> some View {
        content
            .environment(\.bookPalette, store.palette(for: book))
            .environment(\.bookAmbience, BookAmbience.resolve(for: book))
            .task(id: book.id) { await store.resolve(for: book) }
    }
}

extension View {
    /// Bu görünümün altındaki her şeye kitabın rengini ve havasını verir.
    func bookAtmosphere(_ book: BookReference) -> some View {
        modifier(BookAtmosphereModifier(book: book))
    }
}

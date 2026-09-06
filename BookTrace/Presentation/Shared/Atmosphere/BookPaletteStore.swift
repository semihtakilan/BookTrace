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
    // Cached values are derived data. The versioned key replaces the old
    // book-ID cache, whose colors remained stale when a cover changed.
    @ObservationIgnored private static let storageKey = "palette.covers.v2"
    /// Kütüphane büyüdükçe sözlük sınırsız büyümesin.
    @ObservationIgnored private static let storageLimit = 400

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.palettes = Self.loadStored(from: defaults)
    }

    /// Bilinen renk; yoksa kitabın kimliğinden türeyen sabit yedek.
    func palette(for book: BookReference) -> BookPalette {
        palettes[Self.coverIdentity(for: book)] ?? .fallback(for: book.id)
    }

    static func coverIdentity(for book: BookReference) -> String {
        "\(book.id)|\(book.coverURL?.absoluteString ?? "")"
    }

    /// Kapağı indirir (önbellekteyse oradan alır) ve rengini çıkarır.
    ///
    /// Aynı kitap için ikinci bir çağrı iş yapmaz; ekranda aynı kitabın birden
    /// çok kartı olduğunda (raf + arama sonucu) aksi hâlde aynı görsel birkaç
    /// kez çözümleniyordu.
    func resolve(for book: BookReference) async {
        let identity = Self.coverIdentity(for: book)
        guard palettes[identity] == nil, !resolving.contains(identity) else { return }
        guard let url = book.coverURL else { return }

        resolving.insert(identity)
        defer { resolving.remove(identity) }

        guard let result = try? await KingfisherManager.shared.retrieveImage(with: url),
              let palette = BookPaletteExtractor.palette(from: result.image) else { return }

        // Bound the in-memory cache too; the previous cap only affected disk.
        if palettes.count >= Self.storageLimit,
           let evicted = palettes.keys.sorted().first {
            palettes.removeValue(forKey: evicted)
        }
        palettes[identity] = palette
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(palettes) else { return }
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
            .task(id: BookPaletteStore.coverIdentity(for: book)) { await store.resolve(for: book) }
    }
}

extension View {
    /// Bu görünümün altındaki her şeye kitabın rengini ve havasını verir.
    func bookAtmosphere(_ book: BookReference) -> some View {
        modifier(BookAtmosphereModifier(book: book))
    }
}

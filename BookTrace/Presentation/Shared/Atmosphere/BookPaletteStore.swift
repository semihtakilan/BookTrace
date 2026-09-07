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
    @ObservationIgnored private var accessOrder: [String: UInt64]
    @ObservationIgnored private var revision: UInt64
    @ObservationIgnored private var persistedRevision: UInt64 = 0
    @ObservationIgnored private var persistenceTask: Task<Void, Never>?
    @ObservationIgnored private var resolving: Set<String> = []
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let storageLimit: Int
    private static let storageKey = "palette.covers.v3"

    init(defaults: UserDefaults = .standard, storageLimit: Int = 400) {
        self.defaults = defaults
        self.storageLimit = max(1, storageLimit)
        let stored = Self.loadStored(from: defaults)
        let retained = stored.accessOrder.sorted { $0.value > $1.value }.prefix(max(1, storageLimit))
        self.palettes = Dictionary(uniqueKeysWithValues: retained.compactMap { key, _ in
            stored.palettes[key].map { (key, $0) }
        })
        self.accessOrder = Dictionary(uniqueKeysWithValues: retained.map { ($0.key, $0.value) })
        self.revision = stored.accessOrder.values.max() ?? 0
    }

    /// Recency is not observed: reading a color must not invalidate SwiftUI body.
    func palette(for book: BookReference) -> BookPalette {
        let identity = Self.coverIdentity(for: book)
        guard let palette = palettes[identity] else { return .fallback(for: book.id) }
        touch(identity)
        return palette
    }

    static func coverIdentity(for book: BookReference) -> String {
        "\(book.id)|\(book.coverURL?.absoluteString ?? "")"
    }

    func resolve(for book: BookReference) async {
        let identity = Self.coverIdentity(for: book)
        if palettes[identity] != nil {
            touch(identity)
            return
        }
        guard !resolving.contains(identity), let url = book.coverURL else { return }
        resolving.insert(identity)
        defer { resolving.remove(identity) }
        guard let result = try? await KingfisherManager.shared.retrieveImage(with: url),
              let palette = BookPaletteExtractor.palette(from: result.image) else { return }
        store(palette, for: book)
    }

    func store(_ palette: BookPalette, for book: BookReference) {
        let identity = Self.coverIdentity(for: book)
        if palettes[identity] == nil, palettes.count >= storageLimit,
           let evicted = accessOrder.min(by: { $0.value < $1.value })?.key {
            palettes.removeValue(forKey: evicted)
            accessOrder.removeValue(forKey: evicted)
        }
        palettes[identity] = palette
        touch(identity)
    }

    private func touch(_ identity: String) {
        revision += 1
        accessOrder[identity] = revision
        // One pending write per batch; continued scrolling cannot postpone it forever.
        guard persistenceTask == nil else { return }
        persistenceTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            await self?.flush()
        }
    }

    /// Also called when the scene becomes inactive, before the app can be suspended.
    func flush() async {
        persistenceTask?.cancel()
        persistenceTask = nil
        guard revision > persistedRevision else { return }
        let snapshotRevision = revision
        let snapshot = PaletteSnapshot(palettes: palettes, accessOrder: accessOrder)
        let data = await Task.detached(priority: .utility) {
            try? JSONEncoder().encode(snapshot)
        }.value
        // A newer flush may finish first while encoding is off the main actor.
        guard let data, snapshotRevision > persistedRevision else { return }
        defaults.set(data, forKey: Self.storageKey)
        persistedRevision = snapshotRevision
    }

    private static func loadStored(from defaults: UserDefaults) -> PaletteSnapshot {
        if let data = defaults.data(forKey: storageKey),
           let snapshot = try? JSONDecoder().decode(PaletteSnapshot.self, from: data) {
            return snapshot
        }
        // Preserve colors from v2. Its records had no recency, so assign a stable
        // initial order; all subsequent reads and inserts use actual access order.
        let legacy = defaults.data(forKey: "palette.covers.v2")
            .flatMap { try? JSONDecoder().decode([String: BookPalette].self, from: $0) } ?? [:]
        let order = Dictionary(uniqueKeysWithValues: legacy.keys.sorted().enumerated().map {
            ($0.element, UInt64($0.offset + 1))
        })
        return PaletteSnapshot(palettes: legacy, accessOrder: order)
    }
}

nonisolated private struct PaletteSnapshot: Codable, Sendable {
    let palettes: [String: BookPalette]
    let accessOrder: [String: UInt64]
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

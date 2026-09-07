//
//  BookPaletteTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 06.09.2026.
//

import Models
import Testing
import UIKit
@testable import BookTrace

@MainActor
struct BookPaletteTests {
    @Test func paletteWritesAreBatchedAndEvictionUsesLastAccessAcrossLaunches() async throws {
        let suite = "BookPaletteTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = BookPaletteStore(defaults: defaults, storageLimit: 2)
        let first = makeBook(id: "a")
        let second = makeBook(id: "z")
        let third = makeBook(id: "m")
        let color = BookPalette(hue: 0.9, vibrancy: 0.8)
        store.store(color, for: first)
        store.store(color, for: second)
        #expect(defaults.data(forKey: "palette.covers.v3") == nil)
        #expect(store.palette(for: first) == color)
        await store.flush()

        let restored = BookPaletteStore(defaults: defaults, storageLimit: 2)
        restored.store(color, for: third)
        #expect(restored.palette(for: second) == .fallback(for: second.id))
        #expect(restored.palette(for: first) == color)
        #expect(restored.palette(for: third) == color)
        await restored.flush()
        let final = BookPaletteStore(defaults: defaults, storageLimit: 2)
        #expect(final.palette(for: second) == .fallback(for: second.id))
        #expect(final.palette(for: first) == color)
        await final.flush()
    }

    @Test func existingV2PalettesMigrateWithoutDownloadingCovers() async throws {
        let suite = "BookPaletteTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let book = makeBook()
        let color = BookPalette(hue: 0.1, vibrancy: 0.7)
        defaults.set(try JSONEncoder().encode([BookPaletteStore.coverIdentity(for: book): color]), forKey: "palette.covers.v2")
        let store = BookPaletteStore(defaults: defaults)
        #expect(store.palette(for: book) == color)
        await store.flush()
        #expect(defaults.data(forKey: "palette.covers.v3") != nil)
    }

    @Test func changingTheCoverInvalidatesTheCachedColorIdentity() {
        let original = BookReference(id: "book", title: "Book", coverURL: URL(string: "https://example.com/first.jpg"))
        let replacement = BookReference(id: "book", title: "Book", coverURL: URL(string: "https://example.com/second.jpg"))
        #expect(BookPaletteStore.coverIdentity(for: original) != BookPaletteStore.coverIdentity(for: replacement))
    }

    @Test func grayscaleCoversKeepANeutralAtmosphere() throws {
        let palette = try #require(BookPaletteExtractor.palette(from: image(color: .gray)))
        #expect(palette.vibrancy == 0)
        #expect(palette.biased(by: .scienceFiction) == palette)
        #expect(palette.biased(by: .history) == palette)
    }

    @Test func aChromaticCoverKeepsItsOwnHue() throws {
        let palette = try #require(BookPaletteExtractor.palette(from: image(color: UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1))))
        #expect(palette.hue < 0.05 || palette.hue > 0.95)
        #expect(palette.vibrancy > 0.5)
    }

    @Test func fullyTransparentImagesDoNotInventACoverColor() {
        #expect(BookPaletteExtractor.palette(from: image(color: .clear)) == nil)
    }

    private func image(color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 16, height: 24)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 24))
        }
    }
}

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

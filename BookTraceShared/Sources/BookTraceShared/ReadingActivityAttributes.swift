//
//  ReadingActivityAttributes.swift
//  BookTraceShared
//
//  Created by Semih TAKILAN on 07.09.2026.
//

#if os(iOS)
import ActivityKit
import Foundation

public struct ReadingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var clock: ReadingActivityClock
        public var currentPage: Int
        public var pageCount: Int?

        public init(clock: ReadingActivityClock, currentPage: Int, pageCount: Int?) {
            self.clock = clock
            self.currentPage = currentPage
            self.pageCount = pageCount
        }
    }

    public let bookTitle: String
    public let author: String
    public let coverURLString: String?
    public let paletteHue: Double
    public let paletteVibrancy: Double

    public init(bookTitle: String, author: String, coverURLString: String?, paletteHue: Double, paletteVibrancy: Double) {
        self.bookTitle = bookTitle
        self.author = author
        self.coverURLString = coverURLString
        self.paletteHue = paletteHue
        self.paletteVibrancy = paletteVibrancy
    }
}
#endif

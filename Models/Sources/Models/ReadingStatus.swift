//
//  ReadingStatus.swift
//  Models
//
//  Created by Semih TAKILAN on 29.07.2026.
//

import Foundation

public enum ReadingStatus: String, CaseIterable, Codable, Sendable {
    case wishlist
    case toRead
    case reading
    case finished
    case abandoned

    public var systemImage: String {
        switch self {
        case .wishlist:  "sparkles"
        case .toRead:    "bookmark"
        case .reading:   "book"
        case .finished:  "checkmark.seal"
        case .abandoned: "xmark.bin"
        }
    }
}

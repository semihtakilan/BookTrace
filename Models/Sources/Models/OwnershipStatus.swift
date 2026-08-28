//
//  OwnershipStatus.swift
//  Models
//
//  Created by Semih TAKILAN on 11.08.2026.
//

import Foundation

public enum OwnershipStatus: String, CaseIterable, Codable, Sendable {
    case borrowed
    case notOwned
    case owned

    public var displayName: String {
        switch self {
        case .borrowed: "Borrowed"
        case .notOwned: "Not Owned"
        case .owned:    "Owned"
        }
    }

    public var systemImage: String {
        switch self {
        case .borrowed: "hand.raised"
        case .notOwned: "cart"
        case .owned:    "house"
        }
    }
}

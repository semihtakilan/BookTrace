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
}

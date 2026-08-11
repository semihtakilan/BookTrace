//
//  Category.swift
//  Models
//
//  Created by Semih TAKILAN on 11.08.2026.
//

import Foundation

public struct Category: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let name: String
    public let colorHex: String?

    public init(id: String = UUID().uuidString, name: String, colorHex: String? = nil) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
}

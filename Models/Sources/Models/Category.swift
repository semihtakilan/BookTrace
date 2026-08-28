//
//  Category.swift
//  Models
//
//  Created by Semih TAKILAN on 11.08.2026.
//

import Foundation

/// Kullanıcının kendi tanımladığı etiket.
///
/// Kimlik, adın normalize edilmiş hâlidir: aynı etiketi iki kitaba eklemek iki
/// ayrı kategori üretmez, ikisi de tek kayda bağlanır.
public struct Category: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let name: String
    public let colorHex: String?

    /// Ad üzerinden kimlik türeten normal kullanım.
    public init(name: String, colorHex: String? = nil) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = trimmedName
        self.id = Category.normalizedID(for: trimmedName)
        self.colorHex = colorHex
    }

    /// Kalıcı katmandan geri yüklerken kimliği olduğu gibi korumak için.
    public init(id: String, name: String, colorHex: String?) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }

    public static func normalizedID(for name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
    }

    /// "Add to Library" ekranında hazır sunulan etiketler.
    public static let suggested: [Category] = [
        Category(name: "Favorites"),
        Category(name: "Book Club"),
        Category(name: "Work"),
        Category(name: "Reread"),
        Category(name: "Gift")
    ]
}

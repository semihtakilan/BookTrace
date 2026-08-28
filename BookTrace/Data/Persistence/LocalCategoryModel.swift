//
//  LocalCategoryModel.swift
//  Persistence
//
//  Created by Semih TAKILAN on 11.08.2026.
//

import Foundation
import Models
import SwiftData

@Model
final class LocalCategoryModel {
    @Attribute(.unique) var id: String
    var name: String
    var colorHex: String?

    /// Aynı etiket birden çok kayda bağlanabilir; kayıt silinince etiket yaşamaya devam eder.
    @Relationship(deleteRule: .nullify, inverse: \LocalLibraryEntryModel.categories)
    var entries: [LocalLibraryEntryModel] = []

    init(category: Models.Category) {
        id = category.id
        name = category.name
        colorHex = category.colorHex
    }

    func apply(_ category: Models.Category) {
        name = category.name
        colorHex = category.colorHex
    }

    func toDomain() -> Models.Category {
        Models.Category(id: id, name: name, colorHex: colorHex)
    }
}

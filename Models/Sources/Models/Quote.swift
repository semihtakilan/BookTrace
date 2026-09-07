//
//  Quote.swift
//  Models
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation

public struct Quote: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public var text: String
    public var pageNumber: Int? {
        didSet { pageNumber = pageNumber.flatMap { $0 > 0 ? $0 : nil } }
    }
    public var note: String?
    public var createdDate: Date
    public var isFavorite: Bool

    public init(
        id: String = UUID().uuidString,
        text: String,
        pageNumber: Int? = nil,
        note: String? = nil,
        createdDate: Date = Date(),
        isFavorite: Bool = false
    ) {
        self.id = id
        self.text = text
        self.pageNumber = pageNumber.flatMap { $0 > 0 ? $0 : nil }
        self.note = note
        self.createdDate = createdDate
        self.isFavorite = isFavorite
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, pageNumber, note, createdDate, isFavorite
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try values.decode(String.self, forKey: .id),
            text: try values.decode(String.self, forKey: .text),
            pageNumber: try values.decodeIfPresent(Int.self, forKey: .pageNumber),
            note: try values.decodeIfPresent(String.self, forKey: .note),
            createdDate: try values.decode(Date.self, forKey: .createdDate),
            isFavorite: try values.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        )
    }
}

//
//  WorkDetail.swift
//  Models
//
//  Created by Semih TAKILAN on 3.08.2026.
//

import Foundation

public struct WorkDetail: Codable, Sendable {
    public let key: String
    public let title: String
    public let description: String?
    public let subjects: [String]?
    public let firstPublishDate: String?

    enum CodingKeys: String, CodingKey {
        case key, title, subjects, description
        case firstPublishDate = "first_publish_date"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        title = try container.decode(String.self, forKey: .title)
        subjects = try container.decodeIfPresent([String].self, forKey: .subjects)
        firstPublishDate = try container.decodeIfPresent(String.self, forKey: .firstPublishDate)

        if let text = try? container.decode(String.self, forKey: .description) {
            description = text
        } else if let wrapped = try? container.decode(WorkDescriptionValue.self, forKey: .description) {
            description = wrapped.value
        } else {
            description = nil
        }
    }
}

private struct WorkDescriptionValue: Codable, Sendable {
    let value: String
}

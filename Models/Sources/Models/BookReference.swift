//
//  BookReference.swift
//  Models
//
//  Created by Semih TAKILAN on 3.08.2026.
//

import Foundation

public struct BookReference: Identifiable, Hashable, Codable, Sendable {
    public let workKey: String
    public let title: String
    public let authorName: String?
    public let coverId: Int?

    public var id: String { workKey }

    public init(workKey: String, title: String, authorName: String?, coverId: Int?) {
        self.workKey = workKey
        self.title = title
        self.authorName = authorName
        self.coverId = coverId
    }

    public var coverURL: URL? {
        guard let coverId else { return nil }
        return URL(string: "https://covers.openlibrary.org/b/id/\(coverId)-M.jpg")
    }
}

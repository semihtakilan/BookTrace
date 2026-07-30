//
//  Photo.swift
//  Models
//
//  Created by Batuhan Baran on 30.07.2026.
//

import Foundation

public struct Photo: Sendable, Decodable {
    let albumId: String
    let id: String
    let title: String
    let url: String
    let thumbnailUrl: String

    public init(
        albumId: String,
        id: String,
        title: String,
        url: String,
        thumbnailUrl: String
    ) {
        self.albumId = albumId
        self.id = id
        self.title = title
        self.url = url
        self.thumbnailUrl = thumbnailUrl
    }
}

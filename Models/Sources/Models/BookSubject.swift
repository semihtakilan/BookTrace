//
//  BookSubject.swift
//  Models
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Foundation

/// Explore'daki kategori raflarından biri.
///
/// `query`, uzak kaynağa gönderilecek konu terimidir; `displayName` ise
/// kullanıcıya gösterilen etiket.
public struct BookSubject: Identifiable, Hashable, Sendable {
    public let query: String
    public let displayName: String
    public let systemImage: String

    public var id: String { query }

    public init(query: String, displayName: String, systemImage: String) {
        self.query = query
        self.displayName = displayName
        self.systemImage = systemImage
    }

    /// Explore açılışında gösterilen raflar.
    public static let featured: [BookSubject] = [
        BookSubject(query: "fiction", displayName: "Fiction", systemImage: "books.vertical"),
        BookSubject(query: "science fiction", displayName: "Science Fiction", systemImage: "sparkles"),
        BookSubject(query: "history", displayName: "History", systemImage: "clock"),
        BookSubject(query: "philosophy", displayName: "Philosophy", systemImage: "brain"),
        BookSubject(query: "computers", displayName: "Technology", systemImage: "laptopcomputer"),
        BookSubject(query: "biography", displayName: "Biography", systemImage: "person.text.rectangle")
    ]
}

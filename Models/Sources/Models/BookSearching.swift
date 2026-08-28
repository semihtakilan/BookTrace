//
//  BookSearching.swift
//  Models
//
//  Created by Semih TAKILAN on 06.08.2026.
//

import Foundation

/// Uzak kitap kaynağının Domain sözleşmesi.
///
/// Explore'un üç girişi de buradan geçer: serbest metin arama, konu rafı ve ISBN.
public protocol BookSearching: Sendable {
    func searchBooks(query: String, maxResults: Int) async throws -> [BookReference]
    func books(inSubject subject: String, maxResults: Int) async throws -> [BookReference]
    func findBook(isbn: String) async throws -> BookReference
}

public extension BookSearching {
    func searchBooks(query: String) async throws -> [BookReference] {
        try await searchBooks(query: query, maxResults: 20)
    }

    func books(inSubject subject: String) async throws -> [BookReference] {
        try await books(inSubject: subject, maxResults: 15)
    }
}

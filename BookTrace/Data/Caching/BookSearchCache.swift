//
//  BookSearchCache.swift
//  Caching
//
//  Created by Semih TAKILAN on 07.08.2026.
//

import Foundation
import Models

/// Google Books sorgularını diske yazarak uygulama kapanıp açıldığında da hatırlar.
///
/// Anahtar biçimini `CacheFirstBookSearching` belirler; burası yalnızca
/// saklama ve süre dolumuyla ilgilenir.
final class BookSearchCache: BookSearchCaching, @unchecked Sendable {
    private let timeToLive: TimeInterval
    private let fileManager = FileManager.default
    private let directoryURL: URL

    private struct CacheEntry: Codable {
        let books: [BookReference]
        let expiryDate: Date
    }

    init(timeToLive: TimeInterval = 24 * 60 * 60) {
        self.timeToLive = timeToLive

        let cachesDirectory = fileManager
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BookSearchCache", isDirectory: true)
        try? fileManager.createDirectory(at: cachesDirectory, withIntermediateDirectories: true)
        directoryURL = cachesDirectory
    }

    func books(for key: String) -> [BookReference]? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url),
              let entry = try? JSONDecoder().decode(CacheEntry.self, from: data) else {
            return nil
        }

        guard Date() < entry.expiryDate else {
            try? fileManager.removeItem(at: url)
            return nil
        }
        return entry.books
    }

    func store(_ books: [BookReference], for key: String) {
        let entry = CacheEntry(books: books, expiryDate: Date().addingTimeInterval(timeToLive))
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? data.write(to: fileURL(for: key), options: .atomic)
    }

    func removeAll() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ) else { return }
        for file in files {
            try? fileManager.removeItem(at: file)
        }
    }

    /// Anahtarlar `:` ve `"` gibi dosya adında sorun çıkaran karakterler içeriyor,
    /// bu yüzden base64'e çevriliyor.
    private func fileURL(for key: String) -> URL {
        let safeKey = Data(key.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
        return directoryURL.appendingPathComponent("\(safeKey).json")
    }
}

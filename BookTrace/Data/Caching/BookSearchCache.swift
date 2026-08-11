//
//  BookSearchCache.swift
//  Caching
//
//  Created by Semih TAKILAN on 07.08.2026.
//

import Foundation
import Models
import NetworkKit

/// Google Books aramalarını diske kaydederek uygulama kapanıp açıldığında da hatırlanmasını sağlar.
final class BookSearchCache: BookSearchCaching, @unchecked Sendable {
    private let timeToLive: TimeInterval
    private let fileManager = FileManager.default
    
    private struct CacheEntry: Codable {
        let books: [Book]
        let expiryDate: Date
    }

    // Varsayılan olarak 24 saat (60 * 60 * 24) cache'de tutuyoruz
    init(timeToLive: TimeInterval = 24 * 60 * 60) {
        self.timeToLive = timeToLive
    }
    
    private func fileURL(for key: String) -> URL {
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let safeKey = Data(key.utf8).base64EncodedString()
        return cacheDirectory.appendingPathComponent("BookSearchCache_\(safeKey).json")
    }

    func books(for key: String) -> [Book]? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        
        do {
            let entry = try JSONDecoder().decode(CacheEntry.self, from: data)
            if Date() < entry.expiryDate {
                return entry.books
            } else {
                try? fileManager.removeItem(at: url)
                return nil
            }
        } catch {
            return nil
        }
    }

    func store(_ books: [Book], for key: String) {
        let url = fileURL(for: key)
        let entry = CacheEntry(books: books, expiryDate: Date().addingTimeInterval(timeToLive))
        
        do {
            let data = try JSONEncoder().encode(entry)
            try data.write(to: url)
        } catch {
            print("Failed to write cache for \(key): \(error)")
        }
    }
}

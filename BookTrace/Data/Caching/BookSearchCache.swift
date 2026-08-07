//
//  BookSearchCache.swift
//  BookTrace
//

import Foundation
import Models
import NetworkKit

/// Google Books aramalarını varsayılan beş dakika boyunca bellekte tutar.
final class BookSearchCache: BookSearchCaching {
    private let storage: ExpiringMemoryCache<[Book]>

    init(timeToLive: TimeInterval = 5 * 60) {
        storage = ExpiringMemoryCache(timeToLive: timeToLive)
    }

    func books(for key: String) -> [Book]? {
        storage.value(for: key)
    }

    func store(_ books: [Book], for key: String) {
        storage.insert(books, for: key)
    }
}

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
/// saklama, süre dolumu ve boyut sınırıyla ilgilenir.
final class BookSearchCache: BookSearchCaching, @unchecked Sendable {
    private let timeToLive: TimeInterval
    private let maximumByteSize: Int
    private let fileManager = FileManager.default
    private let directoryURL: URL

    private struct CacheEntry: Codable {
        let books: [BookReference]
        let expiryDate: Date
    }

    init(timeToLive: TimeInterval = 24 * 60 * 60, maximumByteSize: Int = 5 * 1024 * 1024) {
        self.timeToLive = timeToLive
        self.maximumByteSize = maximumByteSize

        let cachesDirectory = fileManager
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BookSearchCache", isDirectory: true)
        try? fileManager.createDirectory(at: cachesDirectory, withIntermediateDirectories: true)
        directoryURL = cachesDirectory

        // Süresi dolan dosyalar yalnızca tekrar okunmaya çalışıldığında
        // siliniyordu; bir daha aranmayan sorgular diskte süresiz kalıyordu.
        // Açılışta bir temizlik, dizini kendi kendine toparlar hâle getirir.
        let directory = directoryURL
        Task.detached(priority: .utility) { [timeToLive, maximumByteSize] in
            BookSearchCache.prune(directory: directory, timeToLive: timeToLive, maximumByteSize: maximumByteSize)
        }
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

    /// Süresi dolmuş girdileri siler, ardından dizin bütçeyi aşıyorsa en eski
    /// dosyalardan başlayarak bütçenin altına iner.
    ///
    /// Yazma tarihi süre dolumunu da verdiği için dosyaları açmaya gerek yok.
    private static func prune(directory: URL, timeToLive: TimeInterval, maximumByteSize: Int) {
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]

        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys
        ) else { return }

        var entries: [(url: URL, date: Date, size: Int)] = []
        let now = Date()

        for url in urls {
            let values = try? url.resourceValues(forKeys: Set(keys))
            let date = values?.contentModificationDate ?? .distantPast
            let size = values?.fileSize ?? 0

            if now.timeIntervalSince(date) > timeToLive {
                try? fileManager.removeItem(at: url)
            } else {
                entries.append((url, date, size))
            }
        }

        var total = entries.reduce(0) { $0 + $1.size }
        guard total > maximumByteSize else { return }

        for entry in entries.sorted(by: { $0.date < $1.date }) {
            guard total > maximumByteSize else { break }
            try? fileManager.removeItem(at: entry.url)
            total -= entry.size
        }
    }
}

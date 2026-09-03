//
//  BookCacheSchema.swift
//  Caching
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation
import Models
import SwiftData

/// Cache'lenmiş tek kitap.
///
/// Sorgudan bağımsız saklanıyor: aynı kitap altı rafın üçünde birden geçtiğinde
/// disk üzerinde tek satır oluyor ve detay verisi (açıklama, konular) sonradan
/// geldiğinde o satırın üstüne işleniyor. Sorgu bazlı saklamada aynı kitabın
/// zengin ve fakir kopyaları yan yana durur; hangisinin gösterileceği de
/// kullanıcının hangi ekrandan geldiğine kalırdı.
@Model
final class CachedBookModel {
    // `#Unique`/`#Index` iOS 18 gerektiriyor, dağıtım hedefi 17.6.
    @Attribute(.unique) var id: String = ""
    var title: String = ""
    var authors: [String] = []
    var coverURLString: String?
    var pageCount: Int?
    var publishedDate: String?
    var bookDescription: String?
    var isbn13: String?
    var subjects: [String] = []

    /// LRU budaması için: bütçe aşıldığında en uzun süredir okunmayan gider.
    var lastAccessedAt: Date = Date()

    init(reference: BookReference) {
        id = reference.id
        apply(reference)
    }

    func apply(_ reference: BookReference) {
        title = reference.title
        authors = reference.authors
        coverURLString = reference.coverURL?.absoluteString
        pageCount = reference.pageCount
        publishedDate = reference.publishedDate
        bookDescription = reference.description
        isbn13 = reference.isbn13
        subjects = reference.subjects
    }

    var reference: BookReference {
        BookReference(
            id: id,
            title: title,
            authors: authors,
            coverURL: coverURLString.flatMap(URL.init(string:)),
            pageCount: pageCount,
            publishedDate: publishedDate,
            description: bookDescription,
            isbn13: isbn13,
            subjects: subjects
        )
    }
}

/// Bir sorgunun sonucu: kitapların kendisi değil, sıralı kimlikleri.
///
/// Sıra önemli — arama sonucunun alaka sırası ve rafın kürasyonu bilgi taşıyor;
/// kitapları ilişki olarak tutmak bu sırayı kaybettirirdi.
@Model
final class CachedQueryModel {
    @Attribute(.unique) var key: String = ""
    var bookIDs: [String] = []
    var fetchedAt: Date = Date()
    /// Bu tarihten sonra veri gösterilmeye devam eder, arka planda tazelenir.
    var refreshAfter: Date = Date()
    /// Bu tarihten sonra satır silinir ve sorgu yeniden sorulur.
    var expiresAt: Date = Date()

    init(key: String, bookIDs: [String], query: BookQuery, now: Date = Date()) {
        self.key = key
        self.bookIDs = bookIDs
        fetchedAt = now
        refreshAfter = now.addingTimeInterval(query.refreshInterval)
        expiresAt = now.addingTimeInterval(query.timeToLive)
    }
}

/// Cache mağazasının kurulumu.
///
/// Kütüphaneden ayrı bir container: cache'i temizlemek tek dosya silmek oluyor
/// ve kullanıcının kitapları hiçbir zaman aynı migration'a bağlanmıyor. Dosya
/// Caches dizininde, çünkü içeriği her zaman yeniden üretilebilir — iOS'un yer
/// darlığında silmesi de sorun değil, iCloud yedeğine girmemesi de doğru.
enum BookCacheStorage {
    static let schema = Schema([CachedBookModel.self, CachedQueryModel.self])

    static func makeContainer() throws -> ModelContainer {
        let directory = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let configuration = ModelConfiguration(schema: schema, url: directory.appending(path: "BookCache.store"))
        return try ModelContainer(for: schema, configurations: configuration)
    }
}

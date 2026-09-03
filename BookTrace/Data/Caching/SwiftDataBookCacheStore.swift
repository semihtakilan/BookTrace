//
//  SwiftDataBookCacheStore.swift
//  Caching
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation
import Models
import SwiftData

/// `BookCacheStore`'un SwiftData uygulaması.
///
/// `@ModelActor` olması iki işi birden çözüyor: yazma işleri ana aktörden
/// çıkıyor (raf listeleri kaydırma sırasında kaydediliyordu) ve `ModelContext`
/// tek bir izole bağlamda kalıyor — SwiftData bağlamları thread-safe değil.
@ModelActor
actor SwiftDataBookCacheStore: BookCacheStore {
    /// Kitap satırı bütçesi. Aşıldığında en uzun süredir okunmayanlar gider.
    /// Bir satır birkaç yüz bayt; bu bütçe pratikte birkaç megabayt demek.
    private static let bookLimit = 2_000

    func books(for query: BookQuery) async -> CachedBooks? {
        let key = query.cacheKey
        var descriptor = FetchDescriptor<CachedQueryModel>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1

        guard let record = try? modelContext.fetch(descriptor).first else { return nil }

        let now = Date()
        guard now < record.expiresAt else {
            modelContext.delete(record)
            try? modelContext.save()
            return nil
        }

        // Kitaplardan biri budandıysa liste eksik demektir; eksik bir rafı
        // göstermektense sorguyu ıskalamış saymak daha dürüst.
        let books = fetchBooks(ids: record.bookIDs)
        guard books.count == record.bookIDs.count else {
            modelContext.delete(record)
            try? modelContext.save()
            return nil
        }

        touch(books, at: now)
        try? modelContext.save()

        return CachedBooks(books: books.map(\.reference), isStale: now >= record.refreshAfter)
    }

    func store(_ books: [BookReference], for query: BookQuery) async {
        store(books, for: query, writtenAt: Date())
    }

    /// Yazma tarihi dışarıdan verilebiliyor: tazelik pencereleri gün ölçeğinde,
    /// testin onları gerçek zamanla beklemesi mümkün değil.
    func store(_ books: [BookReference], for query: BookQuery, writtenAt date: Date) {
        for book in books {
            upsert(book)
        }

        let key = query.cacheKey
        var descriptor = FetchDescriptor<CachedQueryModel>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1

        if let existing = try? modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
        }
        modelContext.insert(CachedQueryModel(key: key, bookIDs: books.map(\.id), query: query, now: date))

        try? modelContext.save()
    }

    func book(id: String) async -> BookReference? {
        var descriptor = FetchDescriptor<CachedBookModel>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1

        guard let record = try? modelContext.fetch(descriptor).first else { return nil }
        record.lastAccessedAt = Date()
        try? modelContext.save()
        return record.reference
    }

    func merge(_ book: BookReference) async {
        upsert(book)
        try? modelContext.save()
    }

    func removeAll() async {
        try? modelContext.delete(model: CachedQueryModel.self)
        try? modelContext.delete(model: CachedBookModel.self)
        try? modelContext.save()
    }

    /// Cache'teki kitap satırı sayısı.
    func bookCount() -> Int {
        (try? modelContext.fetchCount(FetchDescriptor<CachedBookModel>())) ?? 0
    }

    /// Tek kitabı düşürür; budamanın sorgular üzerindeki etkisini kurmak için.
    func removeBook(id: String) {
        var descriptor = FetchDescriptor<CachedBookModel>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let record = try? modelContext.fetch(descriptor).first else { return }
        modelContext.delete(record)
        try? modelContext.save()
    }

    /// Süresi dolmuş sorguları ve bütçeyi aşan kitapları siler.
    ///
    /// Açılışta bir kez çağrılır: cache kendi kendini toparlamazsa Caches
    /// dizini sessizce büyür ve bir daha sorulmayacak sorgular orada kalır.
    func prune() async {
        let now = Date()
        try? modelContext.delete(
            model: CachedQueryModel.self,
            where: #Predicate { $0.expiresAt < now }
        )

        var descriptor = FetchDescriptor<CachedBookModel>(
            sortBy: [SortDescriptor(\.lastAccessedAt, order: .reverse)]
        )
        descriptor.propertiesToFetch = [\.id]

        if let books = try? modelContext.fetch(descriptor), books.count > Self.bookLimit {
            for book in books[Self.bookLimit...] {
                modelContext.delete(book)
            }
        }

        try? modelContext.save()
    }

    private func upsert(_ book: BookReference) {
        let id = book.id
        var descriptor = FetchDescriptor<CachedBookModel>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1

        if let existing = try? modelContext.fetch(descriptor).first {
            // Var olan satırı ezmek yerine birleştiriyoruz: listeden gelen kayıt
            // detaydan gelenden fakir, sırayla gelince zengin veri kaybolurdu.
            existing.apply(existing.reference.merging(book))
            existing.lastAccessedAt = Date()
        } else {
            modelContext.insert(CachedBookModel(reference: book))
        }
    }

    private func fetchBooks(ids: [String]) -> [CachedBookModel] {
        let descriptor = FetchDescriptor<CachedBookModel>(predicate: #Predicate { ids.contains($0.id) })
        guard let records = try? modelContext.fetch(descriptor) else { return [] }

        // Fetch sırayı korumuyor; sorgunun sırası (alaka, kürasyon) bilgi taşıyor.
        let byID = Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }
    }

    private func touch(_ books: [CachedBookModel], at date: Date) {
        for book in books {
            book.lastAccessedAt = date
        }
    }
}

/// Cache mağazası açılamadığında devreye giren boş uygulama.
///
/// Cache bir kolaylık; açılmaması uygulamanın çalışmamasını gerektirmiyor.
/// Kullanıcı her isteği ağdan görür, kütüphanesi yerinde durur.
struct DisabledBookCacheStore: BookCacheStore {
    func books(for query: BookQuery) async -> CachedBooks? { nil }
    func store(_ books: [BookReference], for query: BookQuery) async {}
    func book(id: String) async -> BookReference? { nil }
    func merge(_ book: BookReference) async {}
    func removeAll() async {}
}

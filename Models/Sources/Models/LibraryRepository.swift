//
//  LibraryRepository.swift
//  Models
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Foundation

/// Yerel kütüphane için Domain sözleşmesi.
///
/// Somut uygulaması SwiftData'yı bilir; Presentation katmanı yalnızca bu
/// protokolü görür.
@MainActor
public protocol LibraryRepository: AnyObject {
    func fetchEntries() throws -> [LibraryEntry]
    /// Kullanıcının daha önce kullandığı etiketler.
    ///
    /// Etiket önerisi için tüm kütüphaneyi materyalize etmeye gerek yok;
    /// kategoriler zaten ayrı bir tabloda duruyor.
    func fetchCategories() throws -> [Category]
    func entry(for bookID: String) throws -> LibraryEntry?
    func add(_ entry: LibraryEntry) throws
    func update(_ entry: LibraryEntry) throws
    func delete(id: String) throws
    /// Kütüphaneyi ve tüm okuma oturumlarını siler.
    func deleteAll() throws
    /// Oturumu kaydeder, ilerlemeyi işler ve güncellenmiş kaydı döndürür.
    @discardableResult
    func appendSession(_ session: ReadingSession, toEntryWith bookID: String) throws -> LibraryEntry
}

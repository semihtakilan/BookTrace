//
//  LibraryDeduplicator.swift
//  Persistence
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import BookTraceShared
import Foundation
import Models
import SwiftData

/// CloudKit cannot enforce unique constraints. A synced per-row identity makes
/// every device retain the same physical row, even when timestamps are equal.
/// Relationships move before deletion so cascades cannot erase retained history.
@MainActor
enum LibraryDeduplicator {
    @discardableResult
    static func run(in context: ModelContext) throws -> Bool {
        var changed = false
        let records = try context.fetch(FetchDescriptor<LocalLibraryEntryModel>())
        for record in records {
            let canonical = BookIdentifier(rawValue: record.bookID).rawValue
            if record.bookID != canonical { record.bookID = canonical; changed = true }
        }
        for group in Dictionary(grouping: records, by: \.bookID).values where group.count > 1 {
            // A partially imported CloudKit row may not have its identity yet.
            // Wait for it; manufacturing a random ID on each device cannot converge.
            guard group.allSatisfy({ !$0.rowID.isEmpty }) else { continue }
            let ordered = group.sorted { $0.rowID < $1.rowID }
            guard let survivor = ordered.first else { continue }
            let newest = ordered.sorted {
                $0.modifiedDate == $1.modifiedDate ? $0.rowID < $1.rowID : $0.modifiedDate > $1.modifiedDate
            }[0]
            let modifiedDate = group.map(\.modifiedDate).max() ?? survivor.modifiedDate
            var merged = newest.toDomain()
            merged.addedDate = group.map(\.addedDate).min() ?? merged.addedDate
            merged.isFavorite = group.contains { $0.isFavorite }
            let statuses = group.compactMap { ReadingStatus(rawValue: $0.readingStatusRawValue) }
            if statuses.contains(.finished) { merged.setReadingStatus(.finished) }
            else if newest.readingStatusRawValue == ReadingStatus.abandoned.rawValue { merged.setReadingStatus(.abandoned) }
            else if statuses.contains(.reading) { merged.setReadingStatus(.reading) }
            else if statuses.contains(.toRead) { merged.setReadingStatus(.toRead) }
            merged.currentPage = group.map(\.currentPage).max() ?? 0
            if merged.readingStatus == .finished, let total = merged.effectivePageCount { merged.currentPage = max(total, merged.currentPage) }
            merged.finishedDate = group.compactMap(\.finishedDate).max()
            merged.notes = mergedNotes(group.compactMap(\.notes))
            let categories = uniqueObjects(ordered.flatMap(\.categoryRecords)).sorted { $0.rowID < $1.rowID }
            let sessions = uniqueObjects(ordered.flatMap(\.sessionRecords)).sorted { $0.rowID < $1.rowID }
            let quotes = uniqueObjects(ordered.flatMap(\.quoteRecords)).sorted { $0.rowID < $1.rowID }
            survivor.apply(merged, categories: categories)
            survivor.modifiedDate = modifiedDate
            survivor.addedDate = merged.addedDate
            for duplicate in ordered.dropFirst() {
                duplicate.readingSessions = []; duplicate.quotes = []; duplicate.categories = []
            }
            survivor.readingSessions = sessions
            survivor.quotes = quotes
            for session in sessions { session.libraryEntry = survivor }
            for quote in quotes { quote.libraryEntry = survivor }
            for duplicate in ordered.dropFirst() { context.delete(duplicate) }
            changed = true
        }
        for group in Dictionary(grouping: try context.fetch(FetchDescriptor<LocalReadingSessionModel>()), by: \.id).values where group.count > 1 {
            guard group.allSatisfy({ !$0.rowID.isEmpty }) else { continue }
            let ordered = group.sorted { $0.rowID < $1.rowID }
            guard let survivor = ordered.first else { continue }
            // Relationship delivery may lag behind the row. The stable winner
            // can be an orphan while another copy already belongs to its book.
            survivor.libraryEntry = parent(of: group.compactMap(\.libraryEntry))
            survivor.startDate = group.map(\.startDate).min() ?? survivor.startDate
            survivor.durationSeconds = group.map(\.durationSeconds).max() ?? 0
            survivor.pagesRead = group.map(\.pagesRead).max() ?? 0
            for duplicate in ordered.dropFirst() { context.delete(duplicate) }
            changed = true
        }
        for group in Dictionary(grouping: try context.fetch(FetchDescriptor<LocalQuoteModel>()), by: \.id).values where group.count > 1 {
            guard group.allSatisfy({ !$0.rowID.isEmpty }) else { continue }
            let ordered = group.sorted { $0.rowID < $1.rowID }
            guard let survivor = ordered.first else { continue }
            survivor.libraryEntry = parent(of: group.compactMap(\.libraryEntry))
            survivor.createdDate = group.map(\.createdDate).min() ?? survivor.createdDate
            let texts: [String] = group.map { $0.text }
            let orderedTexts = texts.sorted { left, right in
                if left.count == right.count { return left < right }
                return left.count > right.count
            }
            survivor.text = orderedTexts.first ?? survivor.text
            survivor.note = mergedNotes(group.compactMap(\.note))
            survivor.pageNumber = ordered.compactMap(\.pageNumber).first
            survivor.isFavorite = group.contains { $0.isFavorite }
            for duplicate in ordered.dropFirst() { context.delete(duplicate) }
            changed = true
        }
        for group in Dictionary(grouping: try context.fetch(FetchDescriptor<LocalCategoryModel>()), by: \.id).values where group.count > 1 {
            guard group.allSatisfy({ !$0.rowID.isEmpty }) else { continue }
            let ordered = group.sorted { $0.rowID < $1.rowID }
            guard let survivor = ordered.first else { continue }
            survivor.name = ordered.first(where: { !$0.name.isEmpty })?.name ?? survivor.name
            survivor.colorHex = ordered.compactMap(\.colorHex).first
            for entry in uniqueObjects(group.flatMap { $0.entries ?? [] }) {
                // Replacing by logical ID removes all duplicate references too.
                entry.categories = entry.categoryRecords.filter { $0.id != survivor.id } + [survivor]
            }
            for duplicate in ordered.dropFirst() { context.delete(duplicate) }
            changed = true
        }
        for group in Dictionary(grouping: try context.fetch(FetchDescriptor<LocalReadingGoalModel>()), by: \.id).values where group.count > 1 {
            guard group.allSatisfy({ !$0.rowID.isEmpty }) else { continue }
            let ordered = group.sorted { $0.rowID < $1.rowID }
            guard let survivor = ordered.first else { continue }
            let newest = ordered.sorted {
                $0.modifiedDate == $1.modifiedDate ? $0.rowID < $1.rowID : $0.modifiedDate > $1.modifiedDate
            }[0]
            let modifiedDate = group.map(\.modifiedDate).max() ?? survivor.modifiedDate
            survivor.apply(newest.toDomain())
            survivor.modifiedDate = modifiedDate
            for duplicate in ordered.dropFirst() { context.delete(duplicate) }
            changed = true
        }
        if changed { try context.save() }
        return changed
    }

    private static func parent(of candidates: [LocalLibraryEntryModel]) -> LocalLibraryEntryModel? {
        candidates.min { $0.rowID < $1.rowID }
    }

    private static func uniqueObjects<T: AnyObject>(_ objects: [T]) -> [T] {
        var seen = Set<ObjectIdentifier>()
        return objects.filter { seen.insert(ObjectIdentifier($0)).inserted }
    }

    private static func mergedNotes(_ notes: [String]) -> String? {
        let blocks = Set(notes.filter { !$0.isEmpty }).sorted()
        return blocks.isEmpty ? nil : blocks.joined(separator: "\n\n")
    }
}

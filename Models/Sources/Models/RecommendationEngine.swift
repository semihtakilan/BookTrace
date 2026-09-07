//
//  RecommendationEngine.swift
//  Models
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation

public struct BookRecommendation: Identifiable, Hashable, Sendable {
    public let book: BookReference
    public let score: Double
    public var id: String { book.id }
}

/// Local preference scoring; candidates may come from a cached subject shelf.
/// No user reading history leaves the device to produce these scores.
public enum RecommendationEngine {
    public static func recommend(
        candidates: [BookReference], library: [LibraryEntry], limit: Int = 12
    ) -> [BookReference] {
        rankedRecommendations(candidates: candidates, library: library, limit: limit).map(\.book)
    }

    public static func rankedRecommendations(
        candidates: [BookReference], library: [LibraryEntry], limit: Int = 12
    ) -> [BookRecommendation] {
        guard limit > 0 else { return [] }
        let profile = preferenceProfile(library)
        var excluded = Set(library.flatMap { identityKeys($0.book) })
        var results: [BookRecommendation] = []
        for book in candidates {
            let keys = identityKeys(book)
            guard excluded.isDisjoint(with: keys) else { continue }
            excluded.formUnion(keys)
            let subjectScore = Set(book.subjects.map(LibraryAnalytics.normalized))
                .reduce(0.0) { $0 + profile.subjects[$1, default: 0] }
            let authorScore = Set(book.authors.map(LibraryAnalytics.normalized))
                .reduce(0.0) { $0 + profile.authors[$1, default: 0] }
            let score = subjectScore + authorScore
            guard score > 0 else { continue }
            results.append(BookRecommendation(book: book, score: score))
        }
        return Array(results.sorted {
            $0.score == $1.score ? $0.book.id < $1.book.id : $0.score > $1.score
        }.prefix(limit))
    }

    public static func preferredSubjects(in library: [LibraryEntry], limit: Int = 3) -> [String] {
        guard limit > 0 else { return [] }
        return Array(preferenceProfile(library).subjects.filter { $0.value > 0 }.sorted {
            $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value
        }.prefix(limit).map(\.key))
    }

    private static func preferenceProfile(_ library: [LibraryEntry]) -> (subjects: [String: Double], authors: [String: Double]) {
        var subjects: [String: Double] = [:]
        var authors: [String: Double] = [:]
        var seen = Set<String>()
        for entry in library where seen.insert(entry.id).inserted {
            let weight: Double
            switch entry.readingStatus {
            case .finished: weight = Double(entry.rating ?? 3)
            case .reading: weight = 1.5
            case .abandoned: weight = -4
            case .wishlist, .toRead: weight = 0
            }
            let favoriteBonus = entry.isFavorite && entry.readingStatus != .abandoned ? 5.0 : 0
            for subject in Set(entry.book.subjects.map(LibraryAnalytics.normalized)) where !subject.isEmpty {
                subjects[subject, default: 0] += weight + favoriteBonus
            }
            for author in Set(entry.book.authors.map(LibraryAnalytics.normalized)) where !author.isEmpty {
                authors[author, default: 0] += (weight + favoriteBonus) * 1.25
            }
        }
        return (subjects, authors)
    }

    private static func identityKeys(_ book: BookReference) -> Set<String> {
        var keys: Set<String> = ["id:" + book.id]
        if let isbn = book.isbn13?.filter(\.isNumber), !isbn.isEmpty { keys.insert("isbn:" + isbn) }
        if !book.title.isEmpty, !book.authors.isEmpty {
            keys.insert("work:" + LibraryAnalytics.normalized(book.title) + "|"
                + book.authors.map(LibraryAnalytics.normalized).sorted().joined(separator: "|"))
        }
        return keys
    }
}

//
//  LocalRelatedModels.swift
//  BookTraceShared
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation
import Models
import SwiftData

@Model
public final class LocalCategoryModel {
    public var rowID: String = ""
    public var id: String = ""
    public var name: String = ""
    public var colorHex: String?
    @Relationship(deleteRule: .nullify, inverse: \LocalLibraryEntryModel.categories)
    public var entries: [LocalLibraryEntryModel]? = []
    public init(category: Models.Category) {
        rowID = UUID().uuidString
        id = category.id; name = category.name; colorHex = category.colorHex
    }
    public func apply(_ category: Models.Category) { name = category.name; colorHex = category.colorHex }
    public func toDomain() -> Models.Category { Models.Category(id: id, name: name, colorHex: colorHex) }
}

@Model
public final class LocalReadingSessionModel {
    public var rowID: String = ""
    public var id: String = ""
    public var startDate: Date = Date(timeIntervalSince1970: 0)
    public var durationSeconds: Int = 0
    public var pagesRead: Int = 0
    public var libraryEntry: LocalLibraryEntryModel?
    public init(session: ReadingSession) {
        rowID = UUID().uuidString
        id = session.id; startDate = session.startDate
        durationSeconds = session.durationSeconds; pagesRead = session.pagesRead
    }
    public func toDomain() -> ReadingSession {
        ReadingSession(id: id, startDate: startDate, durationSeconds: durationSeconds, pagesRead: pagesRead)
    }
}

@Model
public final class LocalQuoteModel {
    public var rowID: String = ""
    public var id: String = ""
    public var text: String = ""
    public var pageNumber: Int?
    public var note: String?
    public var createdDate: Date = Date(timeIntervalSince1970: 0)
    public var isFavorite: Bool = false
    public var libraryEntry: LocalLibraryEntryModel?
    public init(quote: Quote) { rowID = UUID().uuidString; apply(quote) }
    public func apply(_ quote: Quote) {
        id = quote.id; text = quote.text; pageNumber = quote.pageNumber
        note = quote.note; createdDate = quote.createdDate; isFavorite = quote.isFavorite
    }
    public func toDomain() -> Quote {
        Quote(id: id, text: text, pageNumber: pageNumber, note: note, createdDate: createdDate, isFavorite: isFavorite)
    }
}

@Model
public final class LocalReadingGoalModel {
    public var rowID: String = ""
    public var id: String = ""
    public var periodRawValue: String = "yearly"
    public var metricRawValue: String = "books"
    public var target: Int = 1
    public var startDate: Date = Date(timeIntervalSince1970: 0)
    public var isActive: Bool = true
    public var modifiedDate: Date = Date(timeIntervalSince1970: 0)
    public init(goal: ReadingGoal) { rowID = UUID().uuidString; apply(goal) }
    public func apply(_ goal: ReadingGoal) {
        id = goal.id; periodRawValue = goal.period.rawValue; metricRawValue = goal.metric.rawValue
        target = goal.target; startDate = goal.startDate; isActive = goal.isActive; modifiedDate = Date()
    }
    public func toDomain() -> ReadingGoal {
        ReadingGoal(id: id, period: ReadingGoal.Period(rawValue: periodRawValue) ?? .yearly,
                    metric: ReadingGoal.Metric(rawValue: metricRawValue) ?? .books,
                    target: target, startDate: startDate, isActive: isActive)
    }
}

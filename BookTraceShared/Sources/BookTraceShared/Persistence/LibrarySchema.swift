//
//  LibrarySchema.swift
//  BookTraceShared
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation
import Models
import SwiftData

public enum LibrarySchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(2, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        [LocalLibraryEntryModel.self, LocalReadingSessionModel.self, LocalCategoryModel.self,
         LocalQuoteModel.self, LocalReadingGoalModel.self]
    }
}

public enum LibraryMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [LibrarySchemaV1.self, LibrarySchemaV2.self] }
    public static var stages: [MigrationStage] {
        [.custom(fromVersion: LibrarySchemaV1.self, toVersion: LibrarySchemaV2.self,
                 willMigrate: nil, didMigrate: { context in
            for entry in try context.fetch(FetchDescriptor<LocalLibraryEntryModel>()) {
                entry.rowID = UUID().uuidString
                if entry.readingStatusRawValue == ReadingStatus.finished.rawValue {
                    entry.finishedDate = entry.sessionRecords.map(\.startDate).max()
                }
            }
            for session in try context.fetch(FetchDescriptor<LocalReadingSessionModel>()) { session.rowID = UUID().uuidString }
            for category in try context.fetch(FetchDescriptor<LocalCategoryModel>()) { category.rowID = UUID().uuidString }
            for quote in try context.fetch(FetchDescriptor<LocalQuoteModel>()) { quote.rowID = UUID().uuidString }
            for goal in try context.fetch(FetchDescriptor<LocalReadingGoalModel>()) { goal.rowID = UUID().uuidString }
            try context.save()
        })]
    }
}

public enum LocalStore {
    public static let schema = Schema(versionedSchema: LibrarySchemaV2.self)
    public static let appGroupIdentifier = "group.com.semihtakilan.BookTrace"
    public static let cloudContainerIdentifier = "iCloud.com.semihtakilan.BookTrace"

    public static var groupURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    public static var legacyURL: URL {
        ModelConfiguration(schema: Schema(versionedSchema: LibrarySchemaV1.self), cloudKitDatabase: .none).url
    }

    public static func makeConfiguration() -> ModelConfiguration {
        let url = groupURL.map { $0.appendingPathComponent("LibraryStore/BookTrace.store") } ?? legacyURL
        return ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
    }

    /// Copies an unopened SQLite store and its journal together. The source stays
    /// intact; atomically installing the directory avoids a half-copied destination.
    public static func prepareLocation(legacy: URL, group: URL?, fileManager: FileManager = .default) throws -> URL {
        guard let group else { return legacy }
        let directory = group.appendingPathComponent("LibraryStore", isDirectory: true)
        let destination = directory.appendingPathComponent("BookTrace.store")
        if fileManager.fileExists(atPath: destination.path) { return destination }
        if !fileManager.fileExists(atPath: legacy.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return destination
        }
        let staging = group.appendingPathComponent("LibraryStore-copy-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: legacy.path + suffix)
            if fileManager.fileExists(atPath: source.path) {
                try fileManager.copyItem(at: source, to: staging.appendingPathComponent("BookTrace.store" + suffix))
            }
        }
        // An empty directory can remain after first-launch store creation failed.
        if fileManager.fileExists(atPath: directory.path) {
            guard try fileManager.contentsOfDirectory(atPath: directory.path).isEmpty else {
                throw CocoaError(.fileWriteFileExists)
            }
            try fileManager.removeItem(at: directory)
        }
        try fileManager.moveItem(at: staging, to: directory)
        return destination
    }

    public static func makeContainer() throws -> ModelContainer {
        try open(preferCloud: false).container
    }

    public struct OpenedStore {
        public let container: ModelContainer
        public let cloudEnabled: Bool
        public let sharingAvailable: Bool
    }

    public static func open(preferCloud: Bool) throws -> OpenedStore {
        let group = groupURL
        let url: URL
        do { url = try prepareLocation(legacy: legacyURL, group: group) }
        catch { url = legacyURL }
        let shared = group != nil && url != legacyURL
        if preferCloud && shared {
            do {
                let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .private(cloudContainerIdentifier))
                let container = try ModelContainer(for: schema, migrationPlan: LibraryMigrationPlan.self, configurations: config)
                return OpenedStore(container: container, cloudEnabled: true, sharingAvailable: true)
            } catch {
                // Same URL, same data; unavailable iCloud must never create an empty store.
            }
        }
        let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, migrationPlan: LibraryMigrationPlan.self, configurations: config)
        return OpenedStore(container: container, cloudEnabled: false, sharingAvailable: shared)
    }

    public static func makeWidgetContainer() throws -> ModelContainer {
        guard let group = groupURL else { throw CocoaError(.fileReadNoPermission) }
        let url = group.appendingPathComponent("LibraryStore/BookTrace.store")
        guard FileManager.default.fileExists(atPath: url.path) else { throw CocoaError(.fileNoSuchFile) }
        return try ModelContainer(for: schema, configurations:
            ModelConfiguration(schema: schema, url: url, allowsSave: false, cloudKitDatabase: .none))
    }

    /// Reset both possible locations, including the retained migration copy.
    /// Removing the legacy copy first prevents prepareLocation from replaying
    /// it after a successful reset, and also covers local fallback operation.
    public static func erase(
        legacy: URL = legacyURL,
        group: URL? = groupURL,
        fileManager: FileManager = .default
    ) throws {
        var stores = [legacy]
        if let group { stores.append(group.appendingPathComponent("LibraryStore/BookTrace.store")) }
        var removedPaths = Set<String>()
        for store in stores where removedPaths.insert(store.standardizedFileURL.path).inserted {
            for suffix in ["", "-shm", "-wal"] {
                let file = URL(fileURLWithPath: store.path + suffix)
                if fileManager.fileExists(atPath: file.path) { try fileManager.removeItem(at: file) }
            }
        }
    }
}

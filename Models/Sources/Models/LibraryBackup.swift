//
//  LibraryBackup.swift
//  Models
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation

public struct LibraryBackup: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 2
    public let schemaVersion: Int
    public let exportedAt: Date
    public let entries: [LibraryEntry]
    public let goals: [ReadingGoal]

    public init(exportedAt: Date = Date(), entries: [LibraryEntry], goals: [ReadingGoal] = []) {
        schemaVersion = Self.currentSchemaVersion
        self.exportedAt = exportedAt
        self.entries = entries
        self.goals = goals
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, exportedAt, entries, goals }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        exportedAt = try values.decode(Date.self, forKey: .exportedAt)
        entries = try values.decode([LibraryEntry].self, forKey: .entries)
        goals = try values.decodeIfPresent([ReadingGoal].self, forKey: .goals) ?? []
    }
}

public enum LibraryBackupCodec {
    public enum BackupError: Error, Equatable, LocalizedError {
        case unsupportedVersion(Int)

        public var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version): "This backup uses an unsupported format (version \(version))."
            }
        }
    }

    public static func encode(
        entries: [LibraryEntry], goals: [ReadingGoal] = [], exportedAt: Date = Date()
    ) throws -> Data {
        let encoder = JSONEncoder()
        // Foundation's date numbers preserve sub-second session timing exactly.
        // A versioned, sorted payload remains stable for backup comparisons.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(LibraryBackup(exportedAt: exportedAt, entries: entries, goals: goals))
    }

    public static func decode(_ data: Data) throws -> LibraryBackup {
        let backup = try JSONDecoder().decode(LibraryBackup.self, from: data)
        guard (1...LibraryBackup.currentSchemaVersion).contains(backup.schemaVersion) else {
            throw BackupError.unsupportedVersion(backup.schemaVersion)
        }
        return backup
    }
}

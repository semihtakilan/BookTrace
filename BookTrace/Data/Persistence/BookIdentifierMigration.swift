//
//  BookIdentifierMigration.swift
//  Persistence
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation
import Models
import SwiftData

/// Kütüphanedeki kitap kimliklerini kaynak önekli biçime taşır.
///
/// Tek kaynak varken kimlik Google'ın volume id'siydi (`zyTCAlFPjgYC`); iki
/// kaynak olunca öneki taşıyor (`gb:zyTCAlFPjgYC`). Önek olmadan kaydedilmiş
/// kayıtlar dokunulmadan bırakılırsa aynı kitap kütüphanede iki kez görünür:
/// aramadan gelen `gb:` önekli hâli, kayıtlı olanla eşleşmez.
///
/// Şema değişmediği için bu bir `MigrationStage` değil — yalnızca veri
/// düzeltmesi. Bir kez çalışması yeterli, ama tekrar çalışması da zararsız:
/// zaten önekli kimlikler olduğu gibi kalıyor.
enum BookIdentifierMigration {

    @MainActor
    static func run(in context: ModelContext) {
        guard let records = try? context.fetch(FetchDescriptor<LocalLibraryEntryModel>()) else { return }

        var existingIDs = Set(records.map(\.bookID))
        var didChange = false

        for record in records {
            let canonicalID = BookIdentifier(rawValue: record.bookID).rawValue
            guard canonicalID != record.bookID else { continue }

            // Kanonik hâli zaten kayıtlıysa bu satır onun kopyası demektir;
            // kimliği değiştirmek benzersizlik kısıtını çiğnerdi.
            guard !existingIDs.contains(canonicalID) else { continue }

            existingIDs.remove(record.bookID)
            existingIDs.insert(canonicalID)
            record.bookID = canonicalID
            didChange = true
        }

        guard didChange else { return }
        try? context.save()
    }
}

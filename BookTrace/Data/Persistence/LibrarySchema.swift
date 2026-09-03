//
//  LibrarySchema.swift
//  Persistence
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation
import SwiftData

/// Yerel kütüphanenin ilk şema sürümü.
///
/// Sürümlendirme baştan tanımlı olmasa yalnızca lightweight migration çalışırdı:
/// bir alanın adı değiştiği ya da zorunlu bir alan eklendiği anda mevcut
/// kullanıcıların mağazası açılamaz hâle gelir. Yeni bir sürüm eklerken model
/// tanımları `LibrarySchemaV2` altına kopyalanır, `stages`'e bir
/// `MigrationStage` eklenir ve `schema` yeni sürüme çevrilir.
enum LibrarySchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [LocalLibraryEntryModel.self, LocalReadingSessionModel.self, LocalCategoryModel.self]
    }
}

enum LibraryMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LibrarySchemaV1.self] }

    /// Henüz tek sürüm var; ikinci sürüm eklenince aradaki geçiş buraya girer.
    static var stages: [MigrationStage] { [] }
}

/// Kalıcı mağazanın kurulumu ve — açılamadığında — kurtarılması.
enum LocalStore {
    static let schema = Schema(versionedSchema: LibrarySchemaV1.self)

    static func makeConfiguration() -> ModelConfiguration {
        ModelConfiguration(schema: schema)
    }

    static func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            migrationPlan: LibraryMigrationPlan.self,
            configurations: makeConfiguration()
        )
    }

    /// Mağaza dosyalarını diskten siler.
    ///
    /// Son çare: migration başarısız olduğunda kullanıcının uygulamayı silip
    /// yeniden kurmaktan başka çıkışı olmasın diye. Yan dosyalar (`-shm`,
    /// `-wal`) da gitmezse SQLite eski dosyayı geri kurar.
    static func erase() throws {
        let storeURL = makeConfiguration().url
        let fileManager = FileManager.default

        for url in [storeURL,
                    URL(fileURLWithPath: storeURL.path + "-shm"),
                    URL(fileURLWithPath: storeURL.path + "-wal")] {
            guard fileManager.fileExists(atPath: url.path) else { continue }
            try fileManager.removeItem(at: url)
        }
    }
}

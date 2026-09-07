//
//  EntitlementCache.swift
//  Subscription
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation
import Security

nonisolated protocol EntitlementCaching: Sendable {
    func load() throws -> CachedProEntitlement?
    func save(_ value: CachedProEntitlement) throws
}

nonisolated struct KeychainEntitlementCache: EntitlementCaching {
    private let service = "com.semihtakilan.BookTrace.entitlement"
    private let account = "verified-pro-v1"

    func load() throws -> CachedProEntitlement? {
        var query = identity
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw CacheError(status: status)
        }
        return try JSONDecoder().decode(CachedProEntitlement.self, from: data)
    }

    func save(_ value: CachedProEntitlement) throws {
        let data = try JSONEncoder().encode(value)
        let update = [kSecValueData as String: data]
        var status = SecItemUpdate(identity as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var insert = identity
            insert[kSecValueData as String] = data
            // Neither synchronized to iCloud nor migrated to another device: the
            // second device obtains its entitlement from StoreKit's Apple ID.
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(insert as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw CacheError(status: status) }
    }

    private var identity: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    private struct CacheError: Error { let status: OSStatus }
}

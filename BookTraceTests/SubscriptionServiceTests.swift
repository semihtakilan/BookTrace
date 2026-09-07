//
//  SubscriptionServiceTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation
import Testing
@testable import BookTrace

@MainActor
struct SubscriptionServiceTests {
    @Test(arguments: [true, false])
    func overlappingRefreshesReturnTheCompletedReplacementSnapshot(revoking: Bool) async throws {
        let pro = ProTransactionRecord(productID: ProProductID.lifetime.rawValue, expirationDate: nil)
        let reader = SuspendedEntitlementReader(first: revoking ? [pro] : [], replacement: revoking ? [] : [pro])
        let cache = RecordingEntitlementCache()
        let service = SubscriptionService(
            cache: cache,
            currentEntitlementRecords: { await reader.read() },
            observesStoreKitUpdates: false
        )
        let first = Task { await service.refreshEntitlement() }
        for _ in 0..<200 {
            if await reader.hasStarted { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(await reader.hasStarted)
        let overlapping = Task { await service.refreshEntitlement() }
        // Keep the first snapshot suspended while the second actor call arrives.
        try await Task.sleep(for: .milliseconds(50))
        await reader.resumeFirst()
        let expected: ProEntitlement = revoking ? .free : .pro(source: .lifetime, expirationDate: nil)
        #expect(await first.value == expected)
        #expect(await overlapping.value == expected)
        #expect(await reader.readCount == 2)
        // In particular, an invalidated Pro snapshot must never reach the cache.
        #expect(cache.savedEntitlements == [expected])
    }
}

private actor SuspendedEntitlementReader {
    let first: [ProTransactionRecord]
    let replacement: [ProTransactionRecord]
    private var firstContinuation: CheckedContinuation<Void, Never>?
    private(set) var readCount = 0
    var hasStarted: Bool { firstContinuation != nil }

    init(first: [ProTransactionRecord], replacement: [ProTransactionRecord]) {
        self.first = first
        self.replacement = replacement
    }

    func read() async -> [ProTransactionRecord] {
        readCount += 1
        guard readCount == 1 else { return replacement }
        await withCheckedContinuation { firstContinuation = $0 }
        return first
    }

    func resumeFirst() {
        firstContinuation?.resume()
        firstContinuation = nil
    }
}

private nonisolated final class RecordingEntitlementCache: EntitlementCaching, @unchecked Sendable {
    private let lock = NSLock()
    private var saved: [CachedProEntitlement] = []
    var savedEntitlements: [ProEntitlement] { lock.withLock { saved.map(\.entitlement) } }
    func load() throws -> CachedProEntitlement? { lock.withLock { saved.last } }
    func save(_ value: CachedProEntitlement) throws { lock.withLock { saved.append(value) } }
}

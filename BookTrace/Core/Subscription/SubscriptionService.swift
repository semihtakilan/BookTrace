//
//  SubscriptionService.swift
//  Subscription
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation
import StoreKit

// This actor never publishes unverified purchases or trusts a product ID alone.
nonisolated protocol SubscriptionServing: Sendable {
    func products() async throws -> [Product]
    func purchase(_ product: Product) async throws -> ProPurchaseOutcome
    func refreshEntitlement() async -> ProEntitlement
    func restore() async throws -> ProEntitlement
    func updates() async -> AsyncStream<ProEntitlement>
}

nonisolated enum ProPurchaseOutcome: Sendable, Equatable {
    case purchased, pending, cancelled
}

nonisolated enum SubscriptionError: Error {
    case verificationFailed, productUnavailable, unexpectedPurchaseResult
}

actor SubscriptionService: SubscriptionServing {
    private let cache: any EntitlementCaching
    private var listener: Task<Void, Never>?
    private var statusListener: Task<Void, Never>?
    private var continuations: [UUID: AsyncStream<ProEntitlement>.Continuation] = [:]
    private var refreshRevision: UInt64 = 0
    private var refreshTask: Task<ProEntitlement, Never>?
    private let currentEntitlementRecords: @Sendable () async -> [ProTransactionRecord]
    private let observesStoreKitUpdates: Bool

    init(
        cache: any EntitlementCaching = KeychainEntitlementCache(),
        currentEntitlementRecords: @escaping @Sendable () async -> [ProTransactionRecord] = SubscriptionService.verifiedCurrentEntitlementRecords,
        observesStoreKitUpdates: Bool = true
    ) {
        self.cache = cache
        self.currentEntitlementRecords = currentEntitlementRecords
        self.observesStoreKitUpdates = observesStoreKitUpdates
    }

    deinit {
        listener?.cancel()
        statusListener?.cancel()
    }

    func products() async throws -> [Product] {
        try await Product.products(for: ProProductID.allCases.map(\.rawValue))
    }

    func purchase(_ product: Product) async throws -> ProPurchaseOutcome {
        guard ProProductID(rawValue: product.id) != nil else { throw SubscriptionError.productUnavailable }
        startListening()
        switch try await product.purchase() {
        case .success(let result):
            guard case .verified(let transaction) = result else {
                throw SubscriptionError.verificationFailed
            }
            _ = await refreshEntitlement()
            await transaction.finish()
            return .purchased
        case .pending: return .pending
        case .userCancelled: return .cancelled
        @unknown default: throw SubscriptionError.unexpectedPurchaseResult
        }
    }

    func restore() async throws -> ProEntitlement {
        startListening()
        try await AppStore.sync()
        return await refreshEntitlement()
    }

    func updates() -> AsyncStream<ProEntitlement> {
        startListening()
        let id = UUID()
        let (stream, continuation) = AsyncStream<ProEntitlement>.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuation(id) }
        }
        return stream
    }

    func refreshEntitlement() async -> ProEntitlement {
        startListening()
        refreshRevision &+= 1
        if let refreshTask { return await refreshTask.value }
        // Callers share a completed snapshot. A newer request invalidates a scan
        // already in progress, so neither its caller nor observers see stale data.
        let task = Task { await self.refreshUntilCurrent() }
        refreshTask = task
        return await task.value
    }

    private func refreshUntilCurrent() async -> ProEntitlement {
        while true {
            let revision = refreshRevision
            let records = await currentEntitlementRecords()
            guard revision == refreshRevision else { continue }
            let entitlement = ProEntitlementResolver.resolve(records)
            // An empty, completed sequence is authoritative, including after a
            // refund. A cached purchase must never override verified revocation.
            try? cache.save(CachedProEntitlement(entitlement: entitlement, verifiedAt: .now))
            for continuation in continuations.values { continuation.yield(entitlement) }
            refreshTask = nil
            return entitlement
        }
    }

    private nonisolated static func verifiedCurrentEntitlementRecords() async -> [ProTransactionRecord] {
        var records: [ProTransactionRecord] = []
        for await verification in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verification,
                  ProProductID(rawValue: transaction.productID) != nil else { continue }
            var graceExpiration: Date?
            if let expiration = transaction.expirationDate, expiration <= .now,
               let status = await transaction.subscriptionStatus,
               status.state == .inGracePeriod,
               case .verified(let statusTransaction) = status.transaction,
               statusTransaction.originalID == transaction.originalID,
               statusTransaction.revocationDate == nil,
               case .verified(let renewal) = status.renewalInfo {
                graceExpiration = renewal.gracePeriodExpirationDate
            }
            records.append(ProTransactionRecord(
                productID: transaction.productID,
                expirationDate: transaction.expirationDate,
                revocationDate: transaction.revocationDate,
                isUpgraded: transaction.isUpgraded,
                gracePeriodExpirationDate: graceExpiration
            ))
        }
        return records
    }

    private func startListening() {
        guard observesStoreKitUpdates, listener == nil else { return }
        listener = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { break }
                guard case .verified(let transaction) = result,
                      ProProductID(rawValue: transaction.productID) != nil else { continue }
                // Refund and expiration transactions also need a refresh.
                _ = await self?.refreshEntitlement()
                await transaction.finish()
            }
        }
        statusListener = Task { [weak self] in
            for await status in Product.SubscriptionInfo.Status.updates {
                guard !Task.isCancelled else { break }
                guard case .verified(let transaction) = status.transaction,
                      ProProductID(rawValue: transaction.productID) != nil else { continue }
                _ = await self?.refreshEntitlement()
            }
        }
    }

    private func removeContinuation(_ id: UUID) { continuations[id] = nil }
}

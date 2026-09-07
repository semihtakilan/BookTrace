//
//  ProEntitlementTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation
import StoreKit
import Testing
@testable import BookTrace

struct ProEntitlementTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func verifiedActiveSubscriptionUnlocksPro() {
        let expiration = now.addingTimeInterval(60)
        #expect(ProEntitlementResolver.resolve([
            ProTransactionRecord(productID: ProProductID.yearly.rawValue, expirationDate: expiration)
        ], at: now) == .pro(source: .yearly, expirationDate: expiration))
    }

    @Test func expirationBoundaryIsExclusive() {
        let record = ProTransactionRecord(productID: ProProductID.monthly.rawValue, expirationDate: now)
        #expect(ProEntitlementResolver.resolve([record], at: now) == .free)
        #expect(ProEntitlementResolver.resolve([record], at: now.addingTimeInterval(-1)).isActive(at: now.addingTimeInterval(-1)))
    }

    @Test func revokedUnverifiedAndUpgradedTransactionsNeverUnlock() {
        let expiration = now.addingTimeInterval(600)
        let records = [
            ProTransactionRecord(productID: ProProductID.lifetime.rawValue, expirationDate: nil, revocationDate: now),
            ProTransactionRecord(productID: ProProductID.yearly.rawValue, expirationDate: expiration, isVerified: false),
            ProTransactionRecord(productID: ProProductID.monthly.rawValue, expirationDate: expiration, isUpgraded: true),
            ProTransactionRecord(productID: "an.unrelated.product", expirationDate: expiration)
        ]
        #expect(ProEntitlementResolver.resolve(records, at: now) == .free)
    }

    @Test func lifetimeOutranksSubscriptionRegardlessOfOrder() {
        let subscription = ProTransactionRecord(productID: ProProductID.yearly.rawValue, expirationDate: now.addingTimeInterval(600))
        let lifetime = ProTransactionRecord(productID: ProProductID.lifetime.rawValue, expirationDate: nil)
        #expect(ProEntitlementResolver.resolve([subscription, lifetime], at: now) == .pro(source: .lifetime, expirationDate: nil))
        #expect(ProEntitlementResolver.resolve([lifetime, subscription], at: now) == .pro(source: .lifetime, expirationDate: nil))
    }

    @Test func latestValidPeriodWinsBetweenSubscriptions() {
        let end = now.addingTimeInterval(600)
        #expect(ProEntitlementResolver.resolve([
            ProTransactionRecord(productID: ProProductID.yearly.rawValue, expirationDate: end),
            ProTransactionRecord(productID: ProProductID.monthly.rawValue, expirationDate: now.addingTimeInterval(60))
        ], at: now) == .pro(source: .yearly, expirationDate: end))
    }

    @Test func missingSubscriptionExpiryDoesNotGrantPerpetualPro() {
        #expect(ProEntitlementResolver.resolve([
            ProTransactionRecord(productID: ProProductID.yearly.rawValue, expirationDate: nil)
        ], at: now) == .free)
        #expect(!ProEntitlement.pro(source: .monthly, expirationDate: nil).isActive(at: now))
    }

    @Test func verifiedGracePeriodPreservesAccessUntilItsOwnEnd() {
        // The StoreKit adapter supplies this field only after verifying renewalInfo.
        let graceEnd = now.addingTimeInterval(600)
        let record = ProTransactionRecord(productID: ProProductID.monthly.rawValue,
                                          expirationDate: now.addingTimeInterval(-60),
                                          gracePeriodExpirationDate: graceEnd)
        #expect(ProEntitlementResolver.resolve([record], at: now).isActive(at: now))
        #expect(ProEntitlementResolver.resolve([record], at: graceEnd) == .free)
    }

    @Test func emptyEntitlementsRevokePreviouslyCachedPro() {
        #expect(ProEntitlementResolver.resolve([], at: now) == .free)
    }

    @Test func offlineCachePreservesVerifiedAccessButNeverExtendsItsPeriod() {
        let expiration = now.addingTimeInterval(120)
        let cache = CachedProEntitlement(entitlement: .pro(source: .yearly, expirationDate: expiration), verifiedAt: now)
        #expect(cache.validEntitlement(at: now.addingTimeInterval(60)).isActive(at: now.addingTimeInterval(60)))
        #expect(cache.validEntitlement(at: expiration) == .free)
    }

    @Test func cacheRejectsClockRollbackAndStaleLifetimeAccess() {
        let cache = CachedProEntitlement(entitlement: .pro(source: .lifetime, expirationDate: nil), verifiedAt: now)
        #expect(cache.validEntitlement(at: now.addingTimeInterval(-301)) == .free)
        #expect(cache.validEntitlement(at: now.addingTimeInterval(30 * 24 * 3600)) == .free)
    }

    @Test func cacheRoundTripsWithoutLosingSourceOrExpiry() throws {
        let cache = CachedProEntitlement(entitlement: .pro(source: .monthly, expirationDate: now), verifiedAt: now)
        #expect(try JSONDecoder().decode(CachedProEntitlement.self, from: JSONEncoder().encode(cache)) == cache)
    }

    @Test func allProActionsUseSameEntitlementAndExpiryPolicy() {
        for feature in ProFeature.allCases {
            #expect(!feature.isAvailable(entitlement: .free, at: now))
            #expect(feature.isAvailable(entitlement: .pro(source: .lifetime, expirationDate: nil), at: now))
            #expect(!feature.isAvailable(entitlement: .pro(source: .monthly, expirationDate: now), at: now))
        }
    }

    @Test @MainActor func savingsUsesStorefrontPricesInsteadOfFixedMarketingPercentage() {
        #expect(PaywallViewModel.savingsPercent(monthlyPrice: Decimal(string: "3.99")!, yearlyPrice: Decimal(string: "24.99")!) == 48)
        #expect(PaywallViewModel.savingsPercent(monthlyPrice: Decimal(string: "69.99")!, yearlyPrice: 449) == 47)
        #expect(PaywallViewModel.savingsPercent(monthlyPrice: 0, yearlyPrice: 10) == nil)
        #expect(PaywallViewModel.savingsPercent(monthlyPrice: 1, yearlyPrice: 12) == nil)
    }

    @Test @MainActor func privacyLinksAcceptOnlyConfiguredHTTPSAddresses() {
        #expect(SubscriptionLegalLinks.validHTTPSURL("$(BOOKTRACE_PRIVACY_POLICY_URL)") == nil)
        #expect(SubscriptionLegalLinks.validHTTPSURL("http://example.org/privacy") == nil)
        #expect(SubscriptionLegalLinks.validHTTPSURL("https://user:password@example.org/privacy") == nil)
        #expect(SubscriptionLegalLinks.validHTTPSURL("https://example.org/privacy")?.host == "example.org")
    }
}

@MainActor
struct EntitlementStoreTests {
    @Test func storeStartsFromVerifiedCacheThenAcceptsAuthoritativeRevocation() async {
        let cache = TestEntitlementCache(value: CachedProEntitlement(entitlement: .pro(source: .lifetime, expirationDate: nil), verifiedAt: .now))
        let service = TestSubscriptionService(entitlement: .free)
        let store = EntitlementStore(service: service, cache: cache, sharedDefaults: nil)
        #expect(store.isPro)
        await store.refresh()
        #expect(!store.isPro)
        #expect(store.hasRefreshed)
    }

    @Test func restorePublishesTheServicesEntitlementImmediately() async throws {
        let service = TestSubscriptionService(entitlement: .pro(source: .lifetime, expirationDate: nil))
        let store = EntitlementStore(service: service, cache: TestEntitlementCache(), sharedDefaults: nil)
        #expect(try await store.restore())
        #expect(store.isPro)
        #expect(await service.restoreCount == 1)
    }

    @Test func repeatedStartCreatesOnlyOneLifetimeObserver() async throws {
        let service = TestSubscriptionService(entitlement: .free)
        let store = EntitlementStore(service: service, cache: TestEntitlementCache(), sharedDefaults: nil)
        store.start()
        store.start()
        for _ in 0..<100 where !(await service.hasObserver) { await Task.yield() }
        #expect(await service.observerCount == 1)
        await service.send(.pro(source: .lifetime, expirationDate: nil))
        for _ in 0..<100 where !store.isPro { await Task.yield() }
        #expect(store.isPro)
        await service.send(.free)
        for _ in 0..<100 where store.isPro { await Task.yield() }
        #expect(!store.isPro)
    }

    @Test func annualPlanIsInitiallySelected() {
        let store = EntitlementStore(service: TestSubscriptionService(entitlement: .free), cache: TestEntitlementCache(), sharedDefaults: nil)
        #expect(PaywallViewModel(entitlementStore: store).selectedProductID == .yearly)
    }
}

nonisolated final class TestEntitlementCache: EntitlementCaching, @unchecked Sendable {
    private let lock = NSLock()
    private var value: CachedProEntitlement?
    init(value: CachedProEntitlement? = nil) { self.value = value }
    func load() throws -> CachedProEntitlement? { lock.withLock { value } }
    func save(_ value: CachedProEntitlement) throws { lock.withLock { self.value = value } }
}

private actor TestSubscriptionService: SubscriptionServing {
    var entitlement: ProEntitlement
    var restoreCount = 0
    var observerCount = 0
    private var continuation: AsyncStream<ProEntitlement>.Continuation?
    var hasObserver: Bool { continuation != nil }
    init(entitlement: ProEntitlement) { self.entitlement = entitlement }
    func products() async throws -> [Product] { [] }
    func purchase(_ product: Product) async throws -> ProPurchaseOutcome { .cancelled }
    func refreshEntitlement() async -> ProEntitlement { entitlement }
    func restore() async throws -> ProEntitlement { restoreCount += 1; return entitlement }
    func updates() async -> AsyncStream<ProEntitlement> {
        observerCount += 1
        return AsyncStream { continuation = $0 }
    }
    func send(_ value: ProEntitlement) { entitlement = value; continuation?.yield(value) }
}

//
//  SubscriptionStoreKitTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import BookTrace

/// Real StoreKit 2 transactions in Xcode's isolated local store, never a live charge.
/// StoreKit test settings are process-wide, so these scenarios run serially.
@Suite(.serialized)
@MainActor
struct SubscriptionStoreKitTests {
    @Test func localCatalogMatchesPricingAndTrialPolicy() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let service = SubscriptionService(cache: TestEntitlementCache())
        let products = try await service.products()
        #expect(Set(products.map(\.id)) == Set(ProProductID.allCases.map(\.rawValue)))
        let monthly = try #require(products.first { $0.id == ProProductID.monthly.rawValue })
        let yearly = try #require(products.first { $0.id == ProProductID.yearly.rawValue })
        let lifetime = try #require(products.first { $0.id == ProProductID.lifetime.rawValue })
        #expect(monthly.price == Decimal(string: "3.99"))
        #expect(yearly.price == Decimal(string: "24.99"))
        #expect(lifetime.price == Decimal(string: "59.99"))
        #expect(monthly.type == .autoRenewable)
        #expect(lifetime.type == .nonConsumable)
        #expect(monthly.subscription?.introductoryOffer == nil)
        #expect(lifetime.subscription == nil)
        let offer = try #require(yearly.subscription?.introductoryOffer)
        #expect(offer.paymentMode == .freeTrial)
        #expect(offer.period.value == 1 && offer.period.unit == .week || offer.period.value == 7 && offer.period.unit == .day)
        let store = EntitlementStore(service: service, cache: TestEntitlementCache(), sharedDefaults: nil)
        let viewModel = PaywallViewModel(entitlementStore: store)
        await viewModel.load()
        #expect(viewModel.hasEligibleYearlyTrial)
        #expect(viewModel.yearlySavingsPercent == 48)
    }

    @Test(arguments: ProProductID.allCases)
    func eachProductPurchasesAndRestores(_ productID: ProProductID) async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let service = SubscriptionService(cache: TestEntitlementCache())
        let product = try #require(try await service.products().first { $0.id == productID.rawValue })
        #expect(try await service.purchase(product) == .purchased)
        #expect(await service.refreshEntitlement().source == productID)
        let secondStore = EntitlementStore(service: SubscriptionService(cache: TestEntitlementCache()), cache: TestEntitlementCache(), sharedDefaults: nil)
        #expect(try await secondStore.restore())
        #expect(secondStore.entitlement.source == productID)
    }

    @Test func cancellationKeepsPaidPeriodButExpirationRemovesAccess() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let service = SubscriptionService(cache: TestEntitlementCache())
        let transaction = try await session.buyProduct(identifier: ProProductID.monthly.rawValue)
        #expect(try await waitForEntitlement(service) { $0.source == .monthly }.source == .monthly)
        try session.disableAutoRenewForTransaction(identifier: UInt(transaction.id))
        #expect(await service.refreshEntitlement().isActive())
        try session.expireSubscription(productIdentifier: ProProductID.monthly.rawValue)
        #expect(try await waitForEntitlement(service) { $0 == .free } == .free)
    }

    @Test func trialExpirationAndRefundRemovePro() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let service = SubscriptionService(cache: TestEntitlementCache())
        _ = try await session.buyProduct(identifier: ProProductID.yearly.rawValue)
        #expect(try await waitForEntitlement(service) { $0.source == .yearly }.source == .yearly)
        try session.expireSubscription(productIdentifier: ProProductID.yearly.rawValue)
        #expect(try await waitForEntitlement(service) { $0 == .free } == .free)
        let lifetime = try await session.buyProduct(identifier: ProProductID.lifetime.rawValue)
        #expect(try await waitForEntitlement(service) { $0.source == .lifetime }.source == .lifetime)
        try session.refundTransaction(identifier: UInt(lifetime.id))
        #expect(try await waitForEntitlement(service) { $0 == .free } == .free)
    }

    @Test func userCancellingPurchaseDoesNotUnlockProOrShowAnError() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        let service = SubscriptionService(cache: TestEntitlementCache())
        let store = EntitlementStore(service: service, cache: TestEntitlementCache(), sharedDefaults: nil)
        let viewModel = PaywallViewModel(entitlementStore: store)
        await viewModel.load()
        await viewModel.purchase()
        #expect(!store.isPro)
        #expect(viewModel.message == nil)
    }

    @Test func askToBuyWaitsForApprovalBeforeUnlocking() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        session.askToBuyEnabled = true
        let service = SubscriptionService(cache: TestEntitlementCache())
        let product = try #require(try await service.products().first { $0.id == ProProductID.lifetime.rawValue })
        #expect(try await service.purchase(product) == .pending)
        #expect(await service.refreshEntitlement() == .free)
        let transaction = try #require(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        #expect(try await waitForEntitlement(service) { $0.source == .lifetime }.source == .lifetime)
    }

    @Test func failedRenewalWithoutGraceDoesNotGrantAnotherPeriod() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        session.shouldEnterBillingRetryOnRenewal = true
        session.billingGracePeriodIsEnabled = false
        session.timeRate = .oneRenewalEveryThirtySeconds
        let service = SubscriptionService(cache: TestEntitlementCache())
        let product = try #require(try await service.products().first { $0.id == ProProductID.monthly.rawValue })
        let subscription = try #require(product.subscription)
        _ = try await session.buyProduct(identifier: ProProductID.monthly.rawValue)
        #expect(try await waitForEntitlement(service) { $0.source == .monthly }.source == .monthly)
        // Expiring disables auto-renew, while forceRenewal does not enter retry.
        // Let the accelerated renewal fail and verify StoreKit's actual state.
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(60))
        var retryStatus: Product.SubscriptionInfo.Status?
        repeat {
            retryStatus = try await subscription.status.first { $0.state == .inBillingRetryPeriod }
            if retryStatus != nil { break }
            try await Task.sleep(for: .milliseconds(250))
        } while clock.now < deadline
        let status = try #require(retryStatus)
        guard case .verified(let renewal) = status.renewalInfo,
              case .verified(let transaction) = status.transaction else {
            Issue.record("Billing retry status must contain verified transaction and renewal info")
            return
        }
        #expect(transaction.productID == ProProductID.monthly.rawValue)
        #expect(renewal.isInBillingRetry)
        #expect(renewal.expirationReason == .billingError)
        #expect(renewal.gracePeriodExpirationDate == nil)
        #expect(try await waitForEntitlement(service) { $0 == .free } == .free)
    }

    /// SKTestSession mutations notify StoreKit asynchronously. Poll verified
    /// current entitlements until propagation completes, retaining exact checks.
    private func waitForEntitlement(
        _ service: SubscriptionService,
        matching predicate: (ProEntitlement) -> Bool
    ) async throws -> ProEntitlement {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(10))
        var entitlement: ProEntitlement
        repeat {
            entitlement = await service.refreshEntitlement()
            if predicate(entitlement) { return entitlement }
            try await Task.sleep(for: .milliseconds(100))
        } while clock.now < deadline
        return entitlement
    }

    private func makeSession() throws -> SKTestSession {
        let url = try #require(Bundle(for: SubscriptionTestBundle.self).url(forResource: "BookTrace", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.timeRate = .realTime
        session.storefront = "USA"
        session.locale = Locale(identifier: "en_US")
        return session
    }
}

private final class SubscriptionTestBundle: NSObject {}

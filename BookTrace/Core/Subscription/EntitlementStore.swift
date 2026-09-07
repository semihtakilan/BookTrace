//
//  EntitlementStore.swift
//  Subscription
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation
import Observation
import StoreKit
import WidgetKit

/// The one entitlement source observed by views and injected into Pro view models.
@MainActor
@Observable
final class EntitlementStore {
    private(set) var entitlement: ProEntitlement
    private(set) var hasRefreshed = false

    var isPro: Bool { entitlement.isActive() }

    @ObservationIgnored private let service: any SubscriptionServing
    @ObservationIgnored private let sharedDefaults: UserDefaults?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var expiryTask: Task<Void, Never>?

    init(
        service: (any SubscriptionServing)? = nil,
        cache: any EntitlementCaching = KeychainEntitlementCache(),
        sharedDefaults: UserDefaults? = UserDefaults(suiteName: "group.com.semihtakilan.BookTrace")
    ) {
        self.service = service ?? SubscriptionService(cache: cache)
        self.sharedDefaults = sharedDefaults
        entitlement = (try? cache.load())?.validEntitlement() ?? .free
        publishWidgetAccess()
        scheduleExpiration()
    }

    deinit {
        updatesTask?.cancel()
        expiryTask?.cancel()
    }

    /// Call once at app startup; safe to call again as SwiftUI roots reappear.
    func start() {
        guard updatesTask == nil else { return }
        let service = service
        updatesTask = Task { [weak self] in
            let updates = await service.updates()
            let initial = await service.refreshEntitlement()
            self?.apply(initial)
            for await entitlement in updates {
                guard !Task.isCancelled else { break }
                self?.apply(entitlement)
            }
        }
    }

    func refresh() async { apply(await service.refreshEntitlement()) }
    func products() async throws -> [Product] { try await service.products() }

    func purchase(_ product: Product) async throws -> ProPurchaseOutcome {
        let outcome = try await service.purchase(product)
        if outcome == .purchased { await refresh() }
        return outcome
    }

    @discardableResult
    func restore() async throws -> Bool {
        apply(try await service.restore())
        return isPro
    }

    private func apply(_ value: ProEntitlement) {
        hasRefreshed = true
        let validated = value.isActive() ? value : .free
        guard entitlement != validated else { return }
        entitlement = validated
        publishWidgetAccess()
        scheduleExpiration()
    }

    private func publishWidgetAccess() {
        sharedDefaults?.set(isPro, forKey: "booktrace.pro.enabled")
        sharedDefaults?.set(entitlement.expirationDate, forKey: "booktrace.pro.expiration")
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func scheduleExpiration() {
        expiryTask?.cancel()
        guard let expiration = entitlement.expirationDate else { return }
        let delay = max(0, expiration.timeIntervalSinceNow)
        expiryTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard let self else { return }
            // Revoke promptly even while the app remains foreground/offline;
            // StoreKit may replace it with a verified renewal or grace period.
            self.apply(.free)
            await self.refresh()
        }
    }
}

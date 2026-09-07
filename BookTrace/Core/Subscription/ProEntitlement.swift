//
//  ProEntitlement.swift
//  Subscription
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation

nonisolated enum ProProductID: String, CaseIterable, Codable, Sendable, Identifiable {
    case monthly = "com.semihtakilan.BookTrace.pro.monthly"
    case yearly = "com.semihtakilan.BookTrace.pro.yearly"
    case lifetime = "com.semihtakilan.BookTrace.pro.lifetime"

    var id: String { rawValue }
}

nonisolated enum ProEntitlement: Equatable, Codable, Sendable {
    case free
    case pro(source: ProProductID, expirationDate: Date?)

    func isActive(at date: Date = .now) -> Bool {
        switch self {
        case .free: false
        case let .pro(source, expiration):
            if let expiration { expiration > date }
            else { source == .lifetime }
        }
    }

    var expirationDate: Date? {
        guard case let .pro(_, date) = self else { return nil }
        return date
    }

    var source: ProProductID? {
        guard case let .pro(source, _) = self else { return nil }
        return source
    }
}

/// StoreKit's verified transaction values, kept separate for deterministic policy tests.
nonisolated struct ProTransactionRecord: Sendable {
    let productID: String
    let expirationDate: Date?
    var revocationDate: Date? = nil
    var isUpgraded = false
    var isVerified = true
    var gracePeriodExpirationDate: Date? = nil
}

nonisolated enum ProEntitlementResolver {
    static func resolve(_ records: [ProTransactionRecord], at now: Date = .now) -> ProEntitlement {
        var result: ProEntitlement = .free
        for record in records {
            guard record.isVerified, record.revocationDate == nil, !record.isUpgraded,
                  let source = ProProductID(rawValue: record.productID) else { continue }
            if source == .lifetime { return .pro(source: .lifetime, expirationDate: nil) }
            let expiration = [record.expirationDate, record.gracePeriodExpirationDate]
                .compactMap { $0 }.max()
            guard let expiration, expiration > now else { continue }
            if result.expirationDate == nil || expiration > result.expirationDate! {
                result = .pro(source: source, expirationDate: expiration)
            }
        }
        return result
    }
}

nonisolated struct CachedProEntitlement: Codable, Equatable, Sendable {
    let entitlement: ProEntitlement
    let verifiedAt: Date

    /// No new subscription period is invented offline. Long-lived purchases are
    /// rechecked within 30 days; StoreKit also keeps its own signed offline history.
    func validEntitlement(at now: Date = .now) -> ProEntitlement {
        guard verifiedAt <= now.addingTimeInterval(300),
              now.timeIntervalSince(verifiedAt) < 30 * 24 * 60 * 60,
              entitlement.isActive(at: now) else { return .free }
        return entitlement
    }
}

nonisolated enum ProFeature: String, CaseIterable, Sendable {
    case liveActivity, goals, widgets, statistics, quotes, yearInReview, export

    func isAvailable(entitlement: ProEntitlement, at date: Date = .now) -> Bool {
        entitlement.isActive(at: date)
    }
}

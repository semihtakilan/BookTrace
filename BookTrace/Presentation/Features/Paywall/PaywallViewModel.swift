//
//  PaywallViewModel.swift
//  Paywall
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation
import Observation
import StoreKit
import UIKit

@MainActor
@Observable
final class PaywallViewModel {
    var selectedProductID: ProProductID = .yearly
    private(set) var products: [Product] = []
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    private(set) var hasEligibleYearlyTrial = false
    var message: PaywallMessage?

    @ObservationIgnored private let entitlementStore: EntitlementStore

    init(entitlementStore: EntitlementStore) { self.entitlementStore = entitlementStore }

    var selectedProduct: Product? { products.first { $0.id == selectedProductID.rawValue } }
    var isBusy: Bool { isLoading || isPurchasing || isRestoring }

    var yearlySavingsPercent: Int? {
        guard let monthly = product(.monthly), let yearly = product(.yearly),
              monthly.priceFormatStyle.currencyCode == yearly.priceFormatStyle.currencyCode else { return nil }
        return Self.savingsPercent(monthlyPrice: monthly.price, yearlyPrice: yearly.price)
    }

    static func savingsPercent(monthlyPrice: Decimal, yearlyPrice: Decimal) -> Int? {
        guard monthlyPrice > 0, yearlyPrice > 0 else { return nil }
        let annualized = monthlyPrice * 12
        guard yearlyPrice < annualized else { return nil }
        let savings = NSDecimalNumber(decimal: (annualized - yearlyPrice) / annualized * 100).doubleValue
        let rounded = Int(savings.rounded())
        return rounded > 0 ? min(rounded, 99) : nil
    }

    func product(_ id: ProProductID) -> Product? { products.first { $0.id == id.rawValue } }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let available = try await entitlementStore.products()
            products = ProProductID.allCases.compactMap { id in
                available.first {
                    $0.id == id.rawValue && $0.type == (id == .lifetime ? .nonConsumable : .autoRenewable)
                }
            }
            if products.isEmpty { message = .productsUnavailable }
            if let subscription = product(.yearly)?.subscription,
               let offer = subscription.introductoryOffer,
               offer.paymentMode == .freeTrial,
               offer.periodCount == 1,
               (offer.period.unit == .day && offer.period.value == 7 ||
                offer.period.unit == .week && offer.period.value == 1) {
                hasEligibleYearlyTrial = await subscription.isEligibleForIntroOffer
            } else {
                hasEligibleYearlyTrial = false
            }
        } catch {
            message = .productsUnavailable
        }
    }

    func purchase() async {
        guard !isBusy, let selectedProduct else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await entitlementStore.purchase(selectedProduct) {
            case .purchased:
                if !entitlementStore.isPro { message = .purchaseNotActive }
            case .pending: message = .pending
            case .cancelled: break
            }
        } catch is CancellationError {
            // Leaving Apple's purchase sheet is an expected user action.
        } catch StoreKitError.userCancelled {
        } catch SubscriptionError.verificationFailed {
            message = .verificationFailed
        } catch {
            message = .purchaseFailed
        }
    }

    func restore() async {
        guard !isBusy else { return }
        isRestoring = true
        defer { isRestoring = false }
        do { message = try await entitlementStore.restore() ? .restored : .nothingToRestore }
        catch StoreKitError.userCancelled {}
        catch { message = .restoreFailed }
    }

    func manageSubscriptions() async {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            message = .manageFailed
            return
        }
        do {
            try await AppStore.showManageSubscriptions(in: scene)
            await entitlementStore.refresh()
        } catch { message = .manageFailed }
    }
}

enum PaywallMessage: String, Identifiable {
    case productsUnavailable, pending, verificationFailed, purchaseFailed, purchaseNotActive
    case restored, nothingToRestore, restoreFailed, manageFailed
    var id: String { rawValue }
}

struct SubscriptionLegalLinks {
    let privacyPolicy: URL?
    let termsOfUse: URL

    init(bundle: Bundle = .main) {
        privacyPolicy = Self.validHTTPSURL(bundle.object(forInfoDictionaryKey: "BOOKTRACE_PRIVACY_POLICY_URL") as? String)
        termsOfUse = Self.validHTTPSURL(bundle.object(forInfoDictionaryKey: "BOOKTRACE_TERMS_OF_USE_URL") as? String)
            ?? URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    }

    static func validHTTPSURL(_ value: String?) -> URL? {
        guard let value, !value.contains("$("), let url = URL(string: value),
              url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { return nil }
        return url
    }
}

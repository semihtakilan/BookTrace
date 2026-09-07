//
//  PaywallView.swift
//  Paywall
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(EntitlementStore.self) private var entitlementStore

    var body: some View {
        PaywallContent(viewModel: PaywallViewModel(entitlementStore: entitlementStore))
    }
}

private struct PaywallContent: View {
    @State var viewModel: PaywallViewModel
    @Environment(EntitlementStore.self) private var entitlementStore
    @Environment(\.dismiss) private var dismiss
    @State private var showsPrivacyPolicy = false
    private let legalLinks = SubscriptionLegalLinks()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    introduction
                    benefits
                    if entitlementStore.isPro {
                        activeMembership
                    } else {
                        products
                        purchaseAction
                    }
                    footer
                }
                .padding(24)
            }
            .readingBackground()
            .navigationTitle("BookTrace Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await viewModel.load() }
            .alert(item: $viewModel.message) { message in
                Alert(title: Text(message.titleKey), message: Text(message.detailKey), dismissButton: .default(Text("OK")))
            }
            .sheet(isPresented: $showsPrivacyPolicy) {
                NavigationStack {
                    PrivacyPolicyView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showsPrivacyPolicy = false }
                            }
                        }
                }
            }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "book.pages.fill")
                .font(.largeTitle).foregroundStyle(ReadingStyle.accent)
                .accessibilityHidden(true)
            Text("Make more of your reading.")
                .font(ReadingStyle.title())
                .accessibilityAddTraits(.isHeader)
            Text("A closer look at your reading life, with tools to make it your own.")
                .foregroundStyle(ReadingStyle.secondary)
            Text("Unlimited books, reading sessions, and iCloud sync stay free.")
                .font(.footnote).foregroundStyle(ReadingStyle.secondary)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 16) {
            benefit("Reading on your Lock Screen", symbol: "timer")
            benefit("Goals, widgets, and richer statistics", symbol: "chart.bar.xaxis")
            benefit("A quote notebook with on-device text scanning", symbol: "text.quote")
            benefit("Your full year in review and library exports", symbol: "square.and.arrow.up")
        }
    }

    private func benefit(_ title: LocalizedStringKey, symbol: String) -> some View {
        Label { Text(title) } icon: {
            Image(systemName: symbol).foregroundStyle(ReadingStyle.accent)
                .frame(width: 24).accessibilityHidden(true)
        }
        .font(.subheadline)
    }

    private var products: some View {
        VStack(spacing: 12) {
            if viewModel.isLoading && viewModel.products.isEmpty {
                ProgressView("Loading plans…").frame(maxWidth: .infinity).padding()
            }
            ForEach([ProProductID.yearly, .monthly, .lifetime]) { id in
                if let product = viewModel.product(id) { planRow(product, id: id) }
            }
            if viewModel.products.isEmpty && !viewModel.isLoading {
                Text("Plans are unavailable. Check your connection and try again.")
                    .font(.subheadline).foregroundStyle(ReadingStyle.secondary)
                Button("Try again") { Task { await viewModel.load() } }
                    .buttonStyle(ReadingButtonStyle(prominent: false))
            }
        }
    }

    private func planRow(_ product: Product, id: ProProductID) -> some View {
        let selected = viewModel.selectedProductID == id
        return Button { viewModel.selectedProductID = id } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(ReadingStyle.accent).font(.title3).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(id.titleKey).font(.headline)
                        if id == .yearly, let savings = viewModel.yearlySavingsPercent {
                            Text("Save \(savings)%")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(ReadingStyle.sage, in: .capsule)
                        }
                    }
                    price(product, id: id).font(.subheadline)
                    if id == .yearly && viewModel.hasEligibleYearlyTrial {
                        Text("7 days free for eligible subscribers")
                            .font(.caption).foregroundStyle(ReadingStyle.accent)
                    }
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(ReadingStyle.ink)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ReadingStyle.surface, in: .rect(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(selected ? ReadingStyle.accent : ReadingStyle.line, lineWidth: selected ? 2 : 1) }
            .contentShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isBusy)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func price(_ product: Product, id: ProProductID) -> some View {
        switch id {
        case .monthly: Text("\(product.displayPrice) / month")
        case .yearly: Text("\(product.displayPrice) / year")
        case .lifetime: Text("\(product.displayPrice) once")
        }
    }

    private var purchaseAction: some View {
        VStack(spacing: 12) {
            Button {
                Task { await viewModel.purchase() }
            } label: {
                if viewModel.isPurchasing { ProgressView().tint(ReadingStyle.background) }
                else if viewModel.selectedProductID == .yearly && viewModel.hasEligibleYearlyTrial {
                    Text("Start 7-day free trial")
                } else { Text("Continue with Pro") }
            }
            .buttonStyle(ReadingButtonStyle())
            .disabled(viewModel.isBusy || viewModel.selectedProduct == nil)
            if let product = viewModel.selectedProduct {
                disclosure(product)
                    .font(.caption)
                    .foregroundStyle(ReadingStyle.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func disclosure(_ product: Product) -> some View {
        switch viewModel.selectedProductID {
        case .yearly:
            if viewModel.hasEligibleYearlyTrial {
                Text("7 days free, then \(product.displayPrice) per year. Renews automatically unless canceled. Cancel in Apple subscriptions at least 24 hours before the trial ends to avoid being charged.")
            } else {
                Text("\(product.displayPrice) per year. Renews automatically unless canceled at least 24 hours before the current period ends. Manage or cancel in Apple subscriptions.")
            }
        case .monthly:
            Text("\(product.displayPrice) per month. Renews automatically unless canceled at least 24 hours before the current period ends. Manage or cancel in Apple subscriptions.")
        case .lifetime:
            Text("\(product.displayPrice) as a one-time purchase. No subscription or automatic renewal.")
        }
    }

    private var activeMembership: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("BookTrace Pro is active", systemImage: "checkmark.seal.fill")
                .font(.headline).foregroundStyle(ReadingStyle.accent)
            if entitlementStore.entitlement.source == .lifetime {
                Text("Lifetime access").font(.subheadline)
            } else {
                if let expiration = entitlementStore.entitlement.expirationDate {
                    Text("Access through \(expiration, format: .dateTime.day().month().year())")
                        .font(.subheadline)
                }
                Button("Manage subscriptions") { Task { await viewModel.manageSubscriptions() } }
            }
        }
        .readingCard()
    }

    private var footer: some View {
        VStack(spacing: 16) {
            Button {
                Task { await viewModel.restore() }
            } label: {
                if viewModel.isRestoring { ProgressView("Restoring purchases…") }
                else { Text("Restore Purchases") }
            }
            .disabled(viewModel.isBusy)
            if !entitlementStore.isPro {
                Button("Manage subscriptions") { Task { await viewModel.manageSubscriptions() } }
            }
            HStack(spacing: 24) {
                if let privacyURL = legalLinks.privacyPolicy {
                    Link("Privacy Policy", destination: privacyURL)
                } else {
                    Button("Privacy Policy") { showsPrivacyPolicy = true }
                }
                Link("Terms of Use", destination: legalLinks.termsOfUse)
            }
            .font(.footnote)
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
        .foregroundStyle(ReadingStyle.accent)
    }
}

private extension ProProductID {
    var titleKey: LocalizedStringKey {
        switch self {
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        case .lifetime: "Lifetime"
        }
    }
}

private extension PaywallMessage {
    var titleKey: LocalizedStringKey {
        switch self {
        case .pending: "Purchase pending"
        case .restored: "Purchases restored"
        case .nothingToRestore: "No active purchases"
        default: "Unable to complete request"
        }
    }
    var detailKey: LocalizedStringKey {
        switch self {
        case .productsUnavailable: "Plans could not be loaded. Check your connection and try again."
        case .pending: "Your purchase is waiting for approval. Pro will unlock automatically when Apple confirms it."
        case .verificationFailed: "Apple could not verify this purchase. Please try Restore Purchases or contact support."
        case .purchaseFailed: "The purchase could not be completed. Please try again."
        case .purchaseNotActive: "Apple processed the transaction, but there is no active Pro entitlement yet. Try Restore Purchases."
        case .restored: "Your BookTrace Pro access is available on this device."
        case .nothingToRestore: "No active BookTrace Pro purchase was found for this Apple ID. Check the account used for your original purchase."
        case .restoreFailed: "Purchases could not be restored. Check your connection and try again."
        case .manageFailed: "Subscriptions could not be opened. You can also manage them in your iPhone Settings under your Apple Account."
        }
    }
}

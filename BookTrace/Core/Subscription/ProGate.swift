//
//  ProGate.swift
//  Subscription
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import SwiftUI

/// Apply to the affordance for a Pro action, not to saved user data. Previously
/// saved quotes/goals remain readable after a subscription expires.
private struct ProGate: ViewModifier {
    let feature: ProFeature
    @Environment(EntitlementStore.self) private var entitlementStore
    @State private var presentsPaywall = false

    func body(content: Content) -> some View {
        Group {
            if feature.isAvailable(entitlement: entitlementStore.entitlement) {
                content
            } else {
                content
                    .disabled(true)
                    .accessibilityHidden(true)
                    .overlay {
                        Button { presentsPaywall = true } label: {
                            Color.clear.contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(feature.titleKey)
                        .accessibilityHint("Available with BookTrace Pro")
                    }
            }
        }
        .sheet(isPresented: $presentsPaywall) { PaywallView() }
    }
}

extension View {
    func proGated(feature: ProFeature) -> some View { modifier(ProGate(feature: feature)) }
}

extension ProFeature {
    var titleKey: LocalizedStringKey {
        switch self {
        case .liveActivity: "Live Activity"
        case .goals: "Reading goals"
        case .widgets: "Widgets"
        case .statistics: "Reading statistics"
        case .quotes: "Quote notebook"
        case .yearInReview: "Full year in review"
        case .export: "Export library"
        }
    }
}

//
//  ProfileDestinations.swift
//  Destinations
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import SwiftUI
import NavigatorUI

enum ProfileDestinations: Hashable {
    case settings
}

extension ProfileDestinations: @MainActor NavigationDestination {
    var body: some View {
        switch self {
        case .settings:
            SettingsView()
        }
    }
}

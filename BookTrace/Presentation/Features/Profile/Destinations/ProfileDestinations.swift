//
//  ProfileDestinations.swift
//  Destinations
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import SwiftUI
import NavigatorUI

enum ProfileDestinations: NavigationDestination {
    case settings

    var body: some View {
        switch self {
        case .settings:
            SettingsView()
        }
    }
}

//
//  HomeDestinations.swift
//  BookTrace
//
//  Created by Batuhan Baran on 30.07.2026.
//

import SwiftUI
import NavigatorUI

enum HomeDestinations: NavigationDestination {
    case bookDetail

    var body: some View {
        switch self {
        case .bookDetail:
            Text("BookDetail")
        }
    }
}

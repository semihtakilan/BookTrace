//
//  HomeTab.swift
//  BookTrace
//
//  Created by Batuhan Baran on 30.07.2026.
//

import SwiftUI
import NavigatorUI

struct HomeTab: View {
    @Environment(\.navigator)
    private var navigator

    var body: some View {
        ManagedNavigationStack {
            Button {
                navigator.navigate(to: HomeDestinations.bookDetail)
            } label: {
                Text("Go detail")
            }
        }
    }
}

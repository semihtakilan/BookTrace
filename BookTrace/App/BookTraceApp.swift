//
//  BookTraceApp.swift
//  BookTrace
//
//  Created by Batuhan Baran on 29.07.2026.
//

import SwiftUI
import NavigatorUI
import FactoryKit

@main
struct BookTraceApp: App {

    init() {
        Container.shared.autoRegister()
    }

    var body: some Scene {
        WindowGroup {
            ApplicationRootView()
        }
    }
}

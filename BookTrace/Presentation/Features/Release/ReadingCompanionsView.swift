//
//  ReadingCompanionsView.swift
//  Release
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import SwiftUI

struct ReadingCompanionsView: View {
    @Environment(EntitlementStore.self) private var entitlement
    @State private var showsPaywall = false

    var body: some View {
        List {
            Section {
                Label("Keep your reading close", systemImage: "book.and.wrench")
                    .font(ReadingStyle.title(.title2)).padding(.vertical, 8)
                Text("See your current book, reading streak and goals at a glance with BookTrace Pro.")
                if !entitlement.isPro {
                    Button("Explore BookTrace Pro") { showsPaywall = true }
                }
            }
            Section("Home Screen & Lock Screen widgets") {
                Text("Open the widget gallery from your Home Screen, search for BookTrace, then choose a book, streak or goal widget.")
                Text("For a Lock Screen widget, customize your Lock Screen and select BookTrace from the widget gallery.")
                Text("Open BookTrace once before setting up your widgets. Saving a reading session or updating a goal refreshes their content.")
            }
            Section("Live Activity") {
                Text("With Pro active, start a reading session from a saved book. When allowed by iOS, its timer appears on the Lock Screen and Dynamic Island.")
                Text("Pause, resume, save or cancel the session in BookTrace. The Lock Screen timer follows those changes. Reading sessions work without Pro too.")
                Text("If the timer does not appear, check that Live Activities are enabled for BookTrace in iOS Settings.")
            }
        }
        .navigationTitle("Widgets & Live Activity")
        .sheet(isPresented: $showsPaywall) { PaywallView() }
    }
}

//
//  PersonalBookView.swift
//  Release
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Models
import SwiftUI

struct PersonalBookView: View {
    let bookID: String
    @Environment(ReadingWorkspace.self) private var workspace
    @Environment(\.dismiss) private var dismiss
    @State private var draft = PersonalBookDraft()
    var body: some View {
        Form {
            Section("Your impression") {
                Picker("Your rating", selection: $draft.rating) {
                    Text("Not rated").tag(0)
                    ForEach(1...5, id: \.self) { value in Text(String(repeating: "★", count: value)).tag(value) }
                }
                Toggle("Favorite book", isOn: $draft.favorite)
                TextField("Notes", text: $draft.notes, axis: .vertical).lineLimit(5...12)
            }
            if let entry = workspace.entries.first(where: { $0.id == bookID }), let date = entry.finishedDate {
                LabeledContent("Finished on") { Text(date, style: .date) }
            }
            NavigationLink("Quote notebook") { QuoteNotebookView(bookID: bookID) }
        }
        .navigationTitle("My notes & rating")
        .toolbar { Button("Save") {
            if workspace.mutateEntry(bookID: bookID, { entry in draft.apply(to: &entry) }) { dismiss() }
        }.disabled(!draft.isLoaded) }
        .onAppear {
            if let entry = workspace.entries.first(where: { $0.id == bookID }) {
                draft.load(entry)
            }
        }
        .errorAlert(Binding(get: { workspace.error }, set: { workspace.error = $0 }))
    }
}

/// Keep the editing baseline across child navigation and preserve remote changes
/// to any fields the reader did not change in this form.
struct PersonalBookDraft {
    var rating = 0
    var favorite = false
    var notes = ""
    private var original: LibraryEntry?
    var isLoaded: Bool { original != nil }

    mutating func load(_ entry: LibraryEntry) {
        guard original?.id != entry.id else { return }
        original = entry
        rating = entry.rating ?? 0
        favorite = entry.isFavorite
        notes = entry.notes ?? ""
    }

    func apply(to entry: inout LibraryEntry) {
        guard let original, original.id == entry.id else { return }
        if rating != (original.rating ?? 0) { entry.rating = rating == 0 ? nil : rating }
        if favorite != original.isFavorite { entry.isFavorite = favorite }
        if notes != (original.notes ?? "") { entry.notes = notes.isEmpty ? nil : notes }
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Your books stay yours.").font(.largeTitle.bold())
                Text("BookTrace does not require a BookTrace account and does not include advertising or analytics SDKs.")
                Text("Your library, reading sessions, goals, notes and quotes are stored on your device. When iCloud is available, this data syncs through your private iCloud database using your Apple Account.")
                Text("Search terms and ISBNs are sent to Open Library and, when needed, Google Books. Those services receive network information such as your IP address. Book covers are downloaded from their image services.")
                Text("Camera access is used only when you scan a barcode or a page. Text recognition runs on your device; BookTrace does not upload page photos.")
                Text("Apple processes purchases. BookTrace reads verified purchase status to unlock Pro; it does not receive your payment card details.")
                Text("You choose when to export or share your reading data. Erasing the library removes its books, sessions, notes, quotes and goals; with iCloud enabled, deletions can sync to your other devices.")
                Link("Contact support", destination: URL(string: "mailto:booktrace.help@gmail.com")!)
                Link("Apple standard license agreement", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Text("Last updated: September 7, 2026").font(.footnote).foregroundStyle(.secondary)
            }.padding(24)
        }
        .navigationTitle("Privacy policy")
    }
}

//
//  SettingsView.swift
//  Settings
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import SwiftUI
import Models

struct SettingsView: View {
    @Environment(ViewModelFactory.self) private var viewModelFactory
    @State private var holder = ViewModelHolder<SettingsViewModel>()

    var body: some View {
        SettingsContentView(viewModel: holder { viewModelFactory.makeSettingsViewModel() })
    }
}

private struct SettingsContentView: View {
    @State var viewModel: SettingsViewModel

    @Environment(AppSettings.self) private var settings
    @State private var isConfirmingErase = false

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "book.closed").font(.title2).foregroundStyle(ReadingStyle.accent)
                        .accessibilityHidden(true)
                    Text("Your reading space").font(ReadingStyle.title(.title))
                    Text("A few small things, just the way you like them.")
                        .font(.subheadline).foregroundStyle(ReadingStyle.secondary)
                }
                .padding(.vertical, 10)
            }
            .listRowBackground(ReadingStyle.sage)
            Section {
                Picker(selection: $settings.theme) {
                    ForEach(AppTheme.allCases) { theme in
                        Label(theme.titleKey, systemImage: theme.systemImage).tag(theme)
                    }
                } label: {
                    Text("Theme")
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Appearance")
            }

            Section {
                Picker(selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                } label: {
                    Text("Language")
                }
                .pickerStyle(.menu)
            } header: {
                Text("Language")
            } footer: {
                Text("Applies immediately. Choose System to follow your device language.")
            }

            Section {
                Picker(selection: $settings.defaultReadingStatus) {
                    ForEach(ReadingStatus.allCases, id: \.self) { status in
                        Text(status.titleKey).tag(status)
                    }
                } label: {
                    Text("Reading status")
                }

                Picker(selection: $settings.defaultProgressType) {
                    ForEach(ProgressType.allCases, id: \.self) { type in
                        Text(type.titleKey).tag(type)
                    }
                } label: {
                    Text("Progress type")
                }
            } header: {
                Text("Defaults for new books")
            } footer: {
                Text("The Add to Library form opens with these already selected.")
            }

            Section {
                Button("Clear search cache") { Task { await viewModel.clearSearchCache() } }

                Button(role: .destructive) {
                    isConfirmingErase = true
                } label: {
                    Text("Erase library")
                }
                .disabled(viewModel.libraryCount == 0)
            } header: {
                Text("Data")
            } footer: {
                Text("Search results are cached on this device so browsing works offline and uses fewer requests. Erasing the library removes all \(viewModel.libraryCount) books and their reading sessions.")
            }

            Section {
                LabeledContent("Version", value: viewModel.appVersion)
                LabeledContent("Book data") { Text("Open Library · Google Books") }

                #if DEBUG
                // Hibrit yönlendirmenin ölçüsü: gün boyu kullanımda bu sayı
                // tek haneli kalmalı.
                LabeledContent("Google requests today", value: "\(viewModel.googleRequestsToday)")
                #endif
            } header: {
                Text("About")
            }
        }
        .scrollContentBackground(.hidden)
        .readingBackground()
        .task { await viewModel.loadDiagnostics() }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Erase your library?",
            isPresented: $isConfirmingErase,
            titleVisibility: .visible
        ) {
            Button("Erase", role: .destructive) { viewModel.eraseLibrary() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every book and reading session from this device. It cannot be undone.")
        }
        .alert(item: confirmationBinding) { confirmation in
            Alert(
                title: Text(confirmation.titleKey),
                message: Text(confirmation.messageKey),
                dismissButton: .default(Text("OK")) { viewModel.dismissConfirmation() }
            )
        }
        .errorAlert($viewModel.error)
        .onAppear { viewModel.load() }
    }

    private var confirmationBinding: Binding<SettingsConfirmation?> {
        Binding(
            get: { viewModel.confirmation },
            set: { if $0 == nil { viewModel.dismissConfirmation() } }
        )
    }
}

private extension SettingsConfirmation {
    var titleKey: LocalizedStringKey {
        switch self {
        case .cacheCleared:  "Cache cleared"
        case .libraryErased: "Library erased"
        }
    }

    var messageKey: LocalizedStringKey {
        switch self {
        case .cacheCleared:  "Searches will be fetched fresh from the book catalogs."
        case .libraryErased: "Your library is empty again."
        }
    }
}

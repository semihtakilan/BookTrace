//
//  ReadingSessionView.swift
//  ReadingMode
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import SwiftUI
import NavigatorUI
import Models

/// Okuma oturumu sayaç ekranı.
struct ReadingSessionView: View {
    private let entry: LibraryEntry

    @Environment(ViewModelFactory.self) private var viewModelFactory

    init(entry: LibraryEntry) {
        self.entry = entry
    }

    var body: some View {
        ReadingSessionContent(
            viewModel: viewModelFactory.makeReadingSessionViewModel(entry: entry)
        )
    }
}

private struct ReadingSessionContent: View {
    @State var viewModel: ReadingSessionViewModel

    @Environment(\.navigator) private var navigator
    @Environment(\.scenePhase) private var scenePhase
    @State private var isConfirmingDiscard = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text(viewModel.bookTitle)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(viewModel.isRunning ? "Reading" : "Paused")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(DurationFormatter.timer(seconds: viewModel.elapsedSeconds))
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            Button {
                viewModel.togglePause()
            } label: {
                Label(
                    viewModel.isRunning ? "Pause" : "Resume",
                    systemImage: viewModel.isRunning ? "pause.fill" : "play.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
        .navigationTitle("Reading Mode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { isConfirmingDiscard = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Finish") { viewModel.presentFinishSheet() }
                    .fontWeight(.semibold)
            }
        }
        .task {
            viewModel.start()
            // Saniyelik tik yalnızca görüntüyü tazeler; süre tarihlerden hesaplanır.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                viewModel.tick()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.tick() }
        }
        .onChange(of: viewModel.didSave) { _, didSave in
            if didSave { navigator.dismiss() }
        }
        .sheet(isPresented: $viewModel.isPresentingFinishSheet) {
            FinishSessionSheet(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .confirmationDialog(
            "Discard this session?",
            isPresented: $isConfirmingDiscard,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { navigator.dismiss() }
            Button("Keep Reading", role: .cancel) {}
        } message: {
            Text("The elapsed time will not be recorded.")
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            ),
            actions: { Button("OK", role: .cancel) { viewModel.errorMessage = nil } },
            message: { Text(viewModel.errorMessage ?? "") }
        )
    }
}

/// "Kaç sayfa okudunuz?" girişi — Discard ve Save burada.
private struct FinishSessionSheet: View {
    @Bindable var viewModel: ReadingSessionViewModel

    @Environment(\.navigator) private var navigator
    @FocusState private var isPagesFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Session length", value: DurationFormatter.compact(seconds: viewModel.elapsedSeconds))

                    TextField("Pages read", text: $viewModel.pagesReadText)
                        .keyboardType(.numberPad)
                        .focused($isPagesFieldFocused)
                } header: {
                    Text("How many pages did you read?")
                } footer: {
                    if let projectedPage = viewModel.projectedPage {
                        Text("Progress will move to page \(projectedPage).")
                    }
                }

                Section {
                    Button("Save Session") { viewModel.save() }
                        .disabled(!viewModel.canSave)

                    Button("Discard", role: .destructive) {
                        viewModel.isPresentingFinishSheet = false
                        navigator.dismiss()
                    }
                }
            }
            .navigationTitle("Finish Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { viewModel.resumeAfterCancellingFinish() }
                }
            }
            .onAppear { isPagesFieldFocused = true }
        }
    }
}

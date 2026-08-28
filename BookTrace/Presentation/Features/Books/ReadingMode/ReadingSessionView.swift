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
    @Environment(AppSettings.self) private var settings
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
        .navigationTitle(settings.localized("Reading Mode"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { isConfirmingDiscard = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Finish") { viewModel.beginFinishing() }
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
        .navigationDestination(isPresented: $viewModel.isFinishing) {
            FinishSessionView(viewModel: viewModel)
        }
        // Sistem geri butonu veya kaydırma `isFinishing`'i kendisi kapatıyor;
        // kaydedilmeden dönüldüyse sayaç devam etsin.
        .onChange(of: viewModel.isFinishing) { _, isFinishing in
            if !isFinishing { viewModel.resumeAfterFinishing() }
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
        .errorAlert($viewModel.error)
    }
}

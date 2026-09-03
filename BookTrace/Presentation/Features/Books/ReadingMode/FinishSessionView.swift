//
//  FinishSessionView.swift
//  ReadingMode
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import SwiftUI
import NavigatorUI
import Models

/// Okuma oturumunu kapatma ekranı.
///
/// Sayaç ekranından itilerek açılır: üstte geçen sürenin ayrıntılı hâli, ortada
/// sayfa girişi, altta yan yana Discard ve Save.
struct FinishSessionView: View {
    @Bindable var viewModel: ReadingSessionViewModel

    @Environment(\.navigator) private var navigator
    @FocusState private var isPagesFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            elapsedHeader
            Spacer(minLength: 24)
            pagesInput
            Spacer(minLength: 24)
            actions
        }
        .padding()
        .navigationTitle("Finish Session")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Bölümler

    private var elapsedHeader: some View {
        VStack(spacing: 6) {
            Text(viewModel.bookTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text(viewModel.elapsedDisplay)
                .font(.system(size: 56, weight: .semibold, design: .rounded))
                .monospacedDigit()

            Text("Session length")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var pagesInput: some View {
        VStack(spacing: 12) {
            Text("How many pages did you read?")
                .font(.headline)
                .multilineTextAlignment(.center)

            TextField("0", text: $viewModel.pagesReadText)
                .keyboardType(.numberPad)
                .focused($isPagesFieldFocused)
                .multilineTextAlignment(.center)
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.regularMaterial, in: .rect(cornerRadius: 16))
                // Alanın tamamı dokunulabilir olsun; sadece rakamların üstü değil.
                .contentShape(.rect)
                .onTapGesture { isPagesFieldFocused = true }

            Text("Pages read")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let pagesLimitMessage = viewModel.pagesLimitMessage {
                Text(pagesLimitMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            } else if let projectedPage = viewModel.projectedPage {
                Text("Progress will move to page \(projectedPage).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button(role: .destructive) {
                navigator.dismiss()
            } label: {
                Text("Discard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                viewModel.save()
            } label: {
                Text("Save Session")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canSave)
        }
    }
}

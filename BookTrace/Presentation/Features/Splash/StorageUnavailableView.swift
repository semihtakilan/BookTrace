//
//  StorageUnavailableView.swift
//  Splash
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import SwiftUI

/// Yerel kütüphane açılamadığında gösterilen kurtarma ekranı.
///
/// Buraya düşmenin en olası nedeni başarısız bir şema geçişi. Önceki hâlinde
/// uygulama `fatalError` ile çöküyordu; kullanıcının uygulamayı silip yeniden
/// kurmaktan başka seçeneği yoktu.
struct StorageUnavailableView: View {
    let reason: String
    let onRetry: () -> Void

    @State private var isConfirmingReset = false
    @State private var resetFailure: String?

    var body: some View {
        ContentUnavailableView {
            Label("Your library couldn't be opened", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            VStack(spacing: 10) {
                Text("BookTrace couldn't open the reading data stored on this device.")

                // Teknik ayrıntı: kullanıcı için değil, hata bildiren için.
                Text(resetFailure ?? reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        } actions: {
            VStack(spacing: 12) {
                Button("Try again", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                Button("Reset library data", role: .destructive) {
                    isConfirmingReset = true
                }
            }
        }
        .readingBackground()
        .confirmationDialog(
            "Reset library data?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every book and reading session stored on this device will be deleted. This cannot be undone.")
        }
    }

    private func reset() {
        do {
            try LocalStore.erase()
            resetFailure = nil
            onRetry()
        } catch {
            resetFailure = error.localizedDescription
        }
    }
}

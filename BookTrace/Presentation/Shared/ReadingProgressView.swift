//
//  ReadingProgressView.swift
//  Shared
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import SwiftUI
import Models

/// İlerleme çubuğu ve altında tahmini kalan süre.
///
/// Süre, kitabın kendi okuma oturumlarından türer; hiç oturum yoksa sayfa başına
/// varsayılan hız kullanılır ve bu, metinde açıkça belirtilir.
struct ReadingProgressView: View {
    let entry: LibraryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let fraction = entry.progressFraction, let total = entry.effectivePageCount {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    // Ekranın en önemli bilgisi bu çubukta; değeri açıkça
                    // verilmezse VoiceOver kullanıcısına hiç ulaşmıyor.
                    .accessibilityLabel("Reading progress")
                    .accessibilityValue("\(Int((fraction * 100).rounded()))% complete")

                HStack {
                    Text(progressLabel(fraction: fraction, total: total))
                    Spacer(minLength: 8)
                    if let remainingText {
                        Text(remainingText)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text("Add a page count to track progress")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func progressLabel(fraction: Double, total: Int) -> LocalizedStringKey {
        switch entry.progressType {
        case .pages:
            "\(entry.currentPage) of \(total) pages"
        case .percentage:
            "\(Int((fraction * 100).rounded()))% of \(total) pages"
        }
    }

    private var remainingText: LocalizedStringKey? {
        guard let seconds = entry.estimatedRemainingSeconds else { return nil }
        let formatted = DurationFormatter.compact(seconds: seconds)
        return entry.hasPersonalizedSpeed ? "~\(formatted) left" : "~\(formatted) left (estimate)"
    }
}

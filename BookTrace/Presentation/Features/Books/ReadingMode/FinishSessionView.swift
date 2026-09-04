import SwiftUI
import NavigatorUI
import Models

/// Oturumu kapatma ekranı: ne kadar süre okundu, kaç sayfa ilerlendi.
///
/// Okuma odasının atmosferi burada da sürüyor — kaydetmek ayrı bir forma
/// geçmek gibi değil, aynı anın devamı gibi olsun diye.
struct FinishSessionView: View {
    let viewModel: ReadingSessionViewModel

    var body: some View {
        // Ortam burada yeniden veriliyor: `navigationDestination` içeriği,
        // modifier'ın yazıldığı görünümün değil yığının kökündeki ortamı
        // devralıyor. Bu yüzden okuma odasında verilen renk buraya ulaşmıyordu
        // ve bitirme ekranı varsayılan yeşille açılıyordu.
        FinishSessionContent(viewModel: viewModel)
            .bookAtmosphere(viewModel.entry.book)
    }
}

private struct FinishSessionContent: View {
    @Bindable var viewModel: ReadingSessionViewModel

    @Environment(\.navigator) private var navigator
    @Environment(\.bookPalette) private var palette
    @Environment(\.bookAmbience) private var ambience
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isConfirmingDiscard = false
    @State private var isTypingPages = false
    @State private var typedPages = ""

    private var entry: LibraryEntry { viewModel.entry }

    var body: some View {
        ZStack {
            AmbienceBackdrop(ambience: ambience, palette: palette.biased(by: ambience), isActive: false)

            VStack(spacing: 0) {
                topBar
                GeometryReader { proxy in
                    ScrollView {
                        VStack(spacing: 24) {
                            summary
                            counter
                            if !dynamicTypeSize.isAccessibilitySize {
                                PageDial(pages: pagesBinding,
                                         maximum: viewModel.maximumPages ?? 999,
                                         tint: palette.glow)
                            }
                            note
                            preview
                        }
                        .padding(.horizontal, 26)
                        .padding(.vertical, 18)
                        .frame(maxWidth: 520)
                        // İçerik sığdığında ortalanır, sığmadığında kaydırılır.
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .center)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                actions
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .task {
            // Cetvel her zaman geçerli bir değer gösterir; "sıfır sayfa okudum"
            // da kaydedilebilir bir cevap, kullanıcı ona dokunmak zorunda kalmasın.
            if viewModel.pagesReadText.isEmpty { viewModel.pagesReadText = "0" }
            ReadingHaptics.prepare()
        }
        .alert("Pages read", isPresented: $isTypingPages) {
            TextField("0", text: $typedPages).keyboardType(.numberPad)
            Button("Cancel", role: .cancel) {}
            Button("Set") { viewModel.pagesReadText = typedPages }
        }
        .confirmationDialog("Discard this session?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { navigator.dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("The elapsed time will not be recorded.") }
    }

    // MARK: - Bölümler

    private var topBar: some View {
        HStack {
            Button { viewModel.isFinishing = false } label: {
                Image(systemName: "chevron.left")
                    .font(.callout.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.10), in: .circle)
            }
            .foregroundStyle(.white.opacity(0.8))
            .accessibilityLabel("Back to the timer")

            Spacer(minLength: 8)

            Label(viewModel.elapsedDisplay, systemImage: "clock")
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(.white.opacity(0.10), in: .capsule)
                .accessibilityLabel("Session length")
                .accessibilityValue(viewModel.elapsedDisplay)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var summary: some View {
        VStack(spacing: 10) {
            Text("How far did you get?")
                .font(ReadingStyle.title(.title2))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            Text(entry.book.title)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(2)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 6)
    }

    /// Büyük rakam. Dokununca sayı klavyesi açılır — cetvel hızlı, klavye kesin.
    private var counter: some View {
        Button { presentKeyboardEntry() } label: {
            VStack(spacing: 2) {
                Text(viewModel.pagesReadValue ?? 0, format: .number)
                    .font(.system(size: 76, weight: .light, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .readingAnimation(ReadingMotion.snappy, value: viewModel.pagesReadValue ?? 0)
                Text("pages")
                    .font(.caption.weight(.medium))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pages read, tap to type a number")
        .accessibilityValue("\(viewModel.pagesReadValue ?? 0)")
    }

    @ViewBuilder
    private var note: some View {
        Group {
            if let message = viewModel.pagesLimitMessage {
                Text(message).foregroundStyle(ReadingStyle.gold)
            } else if viewModel.pagesReadValue == 0 {
                Text("You can save your time even if you read zero pages.")
                    .foregroundStyle(.white.opacity(0.5))
            } else if let projectedPage = viewModel.projectedPage {
                Text("Progress will move to page \(projectedPage).")
                    .foregroundStyle(.white.opacity(0.55))
            } else {
                Text("Add a page count to this book to track progress.")
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .font(.footnote)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Kaydedilirse kitabın nereye geleceği. Sayı yerine çubuk, çünkü asıl soru
    /// "kaçıncı sayfa" değil "ne kadarı bitti".
    @ViewBuilder
    private var preview: some View {
        if let total = entry.effectivePageCount, total > 0 {
            let current = Double(entry.currentPage) / Double(total)
            let projected = Double(viewModel.projectedPage ?? entry.currentPage) / Double(total)

            VStack(alignment: .leading, spacing: 10) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.12))
                        Capsule()
                            .fill(palette.glow.opacity(0.45))
                            .frame(width: geometry.size.width * min(1, projected))
                        Capsule()
                            .fill(palette.glow)
                            .frame(width: geometry.size.width * min(1, current))
                    }
                    .readingAnimation(ReadingMotion.progress, value: projected)
                }
                .frame(height: 8)

                HStack {
                    Text("\(entry.currentPage) of \(total) pages")
                    Spacer(minLength: 8)
                    Text("\(Int((projected * 100).rounded()))%")
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.8))
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Projected progress")
            .accessibilityValue("\(Int((projected * 100).rounded()))% complete")
        }
    }

    private var actions: some View {
        VStack(spacing: 6) {
            Button {
                viewModel.save()
                if viewModel.didSave { ReadingHaptics.saved() }
            } label: {
                Label("Save Session", systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(palette.accent(.dark), in: .capsule)
                    .foregroundStyle(.black.opacity(0.85))
                    .opacity(viewModel.canSave ? 1 : 0.4)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSave)

            Button("Discard session", role: .destructive) { isConfirmingDiscard = true }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.55))
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Yardımcılar

    private var pagesBinding: Binding<Int> {
        Binding(
            get: { viewModel.pagesReadValue ?? 0 },
            set: { viewModel.pagesReadText = String($0) }
        )
    }

    private func presentKeyboardEntry() {
        typedPages = String(viewModel.pagesReadValue ?? 0)
        isTypingPages = true
    }
}

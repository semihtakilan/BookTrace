import SwiftUI
import NavigatorUI
import Models

struct ReadingSessionView: View {
    private let entry: LibraryEntry
    @Environment(ViewModelFactory.self) private var viewModelFactory
    @State private var holder = ViewModelHolder<ReadingSessionViewModel>()

    init(entry: LibraryEntry) { self.entry = entry }

    var body: some View {
        ReadingSessionContent(viewModel: holder { viewModelFactory.makeReadingSessionViewModel(entry: entry) })
    }
}

private struct ReadingSessionContent: View {
    @State var viewModel: ReadingSessionViewModel

    var body: some View {
        // Renk ve hava buradan aşağıya veriliyor; okuma odası da bitirme ekranı
        // da aynı kitabın atmosferini paylaşıyor.
        ReadingRoomView(viewModel: viewModel)
            .bookAtmosphere(viewModel.entry.book)
    }
}

/// Okuma odası: kitabın rengiyle boyanmış, türüne göre hareket eden tam ekran.
///
/// Ekranın işi tek bir şey — sayaç. Bu yüzden bilgi az, zemin canlı: kullanıcı
/// telefona değil kitaba bakacak, arada göz attığında da kaldığı yeri hemen
/// görecek.
private struct ReadingRoomView: View {
    @State var viewModel: ReadingSessionViewModel

    @Environment(\.navigator) private var navigator
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.bookPalette) private var palette
    @Environment(\.bookAmbience) private var ambience

    @State private var isConfirmingDiscard = false
    @State private var visibleMilestone: Int?
    @ScaledMetric(relativeTo: .largeTitle) private var timerScale: CGFloat = 1

    private var entry: LibraryEntry { viewModel.entry }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 620

            ZStack {
                AmbienceBackdrop(ambience: ambience, palette: palette.biased(by: ambience),
                                 isActive: viewModel.isRunning)

                VStack(spacing: 0) {
                    roomBar
                    stage(compact: compact, height: geometry.size.height)
                    controls
                }
            }
            .overlay(alignment: .top) { milestoneBanner }
            .overlay { celebration }
        }
        .background(Color.black)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(false)
        .task {
            viewModel.start()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { break }
                viewModel.tick()
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { viewModel.tick() } }
        .onChange(of: viewModel.isReadyToDismiss) { _, ready in if ready { navigator.dismiss() } }
        .onChange(of: viewModel.reachedMilestone) { _, minutes in showMilestone(minutes) }
        .navigationDestination(isPresented: $viewModel.isFinishing) { FinishSessionView(viewModel: viewModel) }
        .onChange(of: viewModel.isFinishing) { _, finishing in
            if !finishing { viewModel.resumeAfterFinishing() }
        }
        .confirmationDialog("Discard this session?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { navigator.dismiss() }
            Button("Keep Reading", role: .cancel) {}
        } message: { Text("The elapsed time will not be recorded.") }
        .errorAlert($viewModel.error)
    }

    // MARK: - Üst şerit

    private var roomBar: some View {
        // Erişilebilirlik boyutlarında oda adı üç satıra çıkıp kapatma
        // düğmesinin üstüne biniyordu; orada alt alta diziliyor.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 8))

        return layout {
            HStack(spacing: 8) {
                Button { isConfirmingDiscard = true } label: {
                    Image(systemName: "xmark")
                        .font(.callout.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.10), in: .circle)
                }
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityLabel("Cancel session")
                if dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            }

            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }

            Label(ambience.roomName, systemImage: ambience.systemImage)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .frame(minHeight: 34)
                .background(.white.opacity(0.08), in: .capsule)

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 8)
                // Solda 44 pt'lik düğme var; sağa aynı boşluk konarak oda adı
                // gerçekten ortalanıyor.
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Sahne

    private func stage(compact: Bool, height: CGFloat) -> some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: compact ? 18 : 26) {
                    if dynamicTypeSize.isAccessibilitySize {
                        // Büyük yazı boyutlarında hepsi ekrana sığmıyor ve
                        // sayaç kaydırma çizgisinin altında kalıyordu. Ekranın
                        // tek işi sayaç olduğu için orada sıra tersine dönüyor.
                        timer(compact: compact)
                        identity
                    } else {
                        book(compact: compact, height: height)
                        identity
                        timer(compact: compact)
                    }
                }
                .padding(.horizontal, 26)
                .padding(.vertical, compact ? 12 : 20)
                .frame(maxWidth: 520)
                // Sahne dikeyde ortalanır; aksi hâlde sayacın altında büyük bir
                // boşluk kalıyor ve ekran yarım görünüyordu.
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func book(compact: Bool, height: CGFloat) -> some View {
        BookVolumeView(
            book: entry.book,
            height: compact ? 132 : min(206, height * 0.27),
            progress: entry.progressFraction,
            isFloating: viewModel.isRunning
        )
        .background {
            // Kitabın arkasındaki hale, kapağın rengini sahneye yayıyor.
            Circle()
                .fill(RadialGradient(colors: [palette.halo.opacity(0.45), .clear],
                                     center: .center, startRadius: 0, endRadius: 190))
                .frame(width: 380, height: 380)
                .blur(radius: 26)
        }
        .padding(.top, compact ? 4 : 12)
    }

    private var identity: some View {
        VStack(spacing: 6) {
            Text(entry.book.title)
                .font(.system(.title3, design: .serif, weight: .medium))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            if !entry.book.author.isEmpty {
                Text(entry.book.author)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func timer(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 12) {
            statusPill

            Text(DurationFormatter.timer(seconds: viewModel.elapsedSeconds))
                // Ölçek sınırlanıyor: erişilebilirlik boyutlarında serbest
                // bırakıldığında rakamlar ekranın yarısını kaplıyordu.
                .font(.system(size: (compact ? 56 : 72) * min(timerScale, 1.3), weight: .regular, design: .serif))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(reduceMotion ? .identity : .numericText())
                .accessibilityLabel("Elapsed time")
                .accessibilityValue(viewModel.elapsedDisplay)

            Text(ambience.invitation)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            // Nokta yalnızca sayaç işlerken nefes alıyor; duraklamış bir oturum
            // ekranda da durmuş görünüyor.
            Circle()
                .fill(viewModel.isRunning ? palette.glow : ReadingStyle.gold)
                .frame(width: 7, height: 7)
                .modifier(PulsingDot(isActive: viewModel.isRunning && !reduceMotion))
                .accessibilityHidden(true)
            Text(viewModel.isRunning ? "Reading" : "Paused")
                .font(.caption2.weight(.semibold))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Denetimler

    private var controls: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 14))

        return layout {
            Button {
                viewModel.togglePause()
                ReadingHaptics.toggle()
            } label: {
                Label(viewModel.isRunning ? "Pause" : "Resume",
                      systemImage: viewModel.isRunning ? "pause.fill" : "play.fill")
                    .labelStyle(PauseLabelStyle(showsTitle: dynamicTypeSize.isAccessibilitySize))
                    .font(.title3)
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 62, minHeight: 62)
                    .background(.white.opacity(0.14),
                                in: dynamicTypeSize.isAccessibilitySize ? AnyShape(Capsule()) : AnyShape(Circle()))
                    .overlay {
                        (dynamicTypeSize.isAccessibilitySize ? AnyShape(Capsule()) : AnyShape(Circle()))
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    }
                    .foregroundStyle(.white)
            }
            .accessibilityLabel(viewModel.isRunning ? "Pause" : "Resume")

            Button { viewModel.beginFinishing() } label: {
                Label("Finish reading", systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .background(palette.accent(.dark), in: .capsule)
                    .foregroundStyle(.black.opacity(0.85))
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
        .padding(.top, 6)
    }

    // MARK: - Katmanlar

    @ViewBuilder
    private var milestoneBanner: some View {
        if let visibleMilestone {
            SessionMilestoneToast(minutes: visibleMilestone)
                .padding(.top, 58)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var celebration: some View {
        if let outcome = viewModel.outcome {
            SessionCelebrationView(outcome: outcome) { viewModel.acknowledgeOutcome() }
                .transition(.opacity)
        }
    }

    private func showMilestone(_ minutes: Int?) {
        guard let minutes else { return }
        ReadingHaptics.step()
        withAnimation(reduceMotion ? nil : ReadingMotion.gentle) { visibleMilestone = minutes }
        viewModel.clearMilestone()

        Task {
            try? await Task.sleep(for: .seconds(3.4))
            withAnimation(reduceMotion ? nil : ReadingMotion.gentle) {
                // Bu arada yeni bir eşik geldiyse onun bildirimi kalmalı.
                if visibleMilestone == minutes { visibleMilestone = nil }
            }
        }
    }
}

/// Sayaç işlerken nefes alan durum noktası.
private struct PulsingDot: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            TimelineView(.animation(minimumInterval: ReadingMotion.ambientFrameInterval)) { context in
                let phase = context.date.timeIntervalSinceReferenceDate * 1.6
                content
                    .scaleEffect(1 + 0.35 * (0.5 + 0.5 * sin(phase)))
                    .opacity(0.55 + 0.45 * (0.5 + 0.5 * sin(phase)))
            }
        } else {
            content
        }
    }
}

/// Duraklat düğmesi normalde yalnızca simge; erişilebilirlik boyutlarında
/// yazıyla birlikte, çünkü orada tek başına simge küçük ve belirsiz kalıyor.
private struct PauseLabelStyle: LabelStyle {
    let showsTitle: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon
            if showsTitle { configuration.title.font(.headline) }
        }
    }
}

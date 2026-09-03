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
    @Environment(\.navigator) private var navigator
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isConfirmingDiscard = false
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize: CGFloat = 66

    var body: some View {
        GeometryReader { geometry in
        let compact = geometry.size.height < 560
        ScrollView {
            VStack(spacing: compact ? 16 : 30) {
                VStack(spacing: 10) {
                    ReadingEyebrow(title: "A MOMENT FOR YOURSELF")
                    Text("Settle into your story.").font(ReadingStyle.title(compact ? .title2 : .title))
                        .multilineTextAlignment(.center)
                }
                if !dynamicTypeSize.isAccessibilitySize {
                RemoteBookCover(url: viewModel.entry.book.coverURL, width: compact ? 64 : 104, height: compact ? 96 : 156, contentMode: .fit,
                                fallbackTitle: viewModel.bookTitle, fallbackAuthor: viewModel.entry.book.author)
                    .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
                }
                VStack(spacing: 8) {
                    Text(viewModel.bookTitle).font(.system(.title3, design: .serif)).multilineTextAlignment(.center)
                    Text(viewModel.entry.book.author).font(.subheadline).foregroundStyle(ReadingStyle.secondary)
                        .multilineTextAlignment(.center)
                }
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Circle().fill(viewModel.isRunning ? ReadingStyle.accent : ReadingStyle.gold).frame(width: 6, height: 6)
                            .accessibilityHidden(true)
                        Text(viewModel.isRunning ? "Reading" : "Paused")
                            .font(.caption.weight(.medium)).tracking(1.5).textCase(.uppercase)
                    }
                    Text(DurationFormatter.timer(seconds: viewModel.elapsedSeconds))
                        .font(.system(size: timerSize, weight: .regular, design: .serif))
                        .monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.4)
                        .contentTransition(reduceMotion ? .identity : .numericText())
                        .accessibilityLabel("Elapsed time")
                        .accessibilityValue(viewModel.elapsedDisplay)
                    Text("Just you and the next page.")
                        .font(.subheadline).foregroundStyle(ReadingStyle.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, compact ? 12 : 22)
                .background(ReadingStyle.sage.opacity(0.5), in: .rect(cornerRadius: 28))
            }
            .padding(.horizontal, 24).padding(.vertical, compact ? 12 : 24)
            .frame(maxWidth: 600).frame(maxWidth: .infinity)
        }
        }
        .readingBackground()
        .navigationTitle("Reading Mode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { isConfirmingDiscard = true } label: { Image(systemName: "xmark") }
                    .accessibilityLabel("Cancel session")
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button { viewModel.togglePause() } label: {
                    Label(viewModel.isRunning ? "Pause" : "Resume", systemImage: viewModel.isRunning ? "pause.fill" : "play.fill")
                }
                .buttonStyle(ReadingButtonStyle(prominent: false))
                Button("Finish reading") { viewModel.beginFinishing() }
                    .buttonStyle(ReadingButtonStyle())
            }
            .padding(.horizontal, 24).padding(.vertical, 12)
            .frame(maxWidth: 600).frame(maxWidth: .infinity)
            .background(ReadingStyle.background)
        }
        .task {
            viewModel.start()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { break }
                viewModel.tick()
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { viewModel.tick() } }
        .onChange(of: viewModel.didSave) { _, saved in if saved { navigator.dismiss() } }
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
}

import SwiftUI
import NavigatorUI
import Models

struct FinishSessionView: View {
    @Bindable var viewModel: ReadingSessionViewModel
    @Environment(\.navigator) private var navigator
    @FocusState private var isPagesFieldFocused: Bool
    @State private var isConfirmingDiscard = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                if isPagesFieldFocused {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(viewModel.bookTitle)
                            .font(.system(.subheadline, design: .serif)).lineLimit(2)
                        Spacer(minLength: 0)
                        Label(viewModel.elapsedDisplay, systemImage: "clock")
                            .font(.subheadline.monospacedDigit()).foregroundStyle(ReadingStyle.accent)
                    }
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "book.closed.fill").font(.title2)
                            .foregroundStyle(ReadingStyle.accent)
                            .frame(width: 62, height: 62).background(ReadingStyle.sage, in: .circle)
                            .accessibilityHidden(true)
                        Text("A few pages further.").font(ReadingStyle.title(.title))
                        Text(viewModel.bookTitle).font(.subheadline).foregroundStyle(ReadingStyle.secondary)
                        Label(viewModel.elapsedDisplay, systemImage: "clock")
                            .font(.title3.monospacedDigit()).foregroundStyle(ReadingStyle.accent)
                            .accessibilityLabel("Session length").accessibilityValue(viewModel.elapsedDisplay)
                    }
                    .multilineTextAlignment(.center)
                }
                VStack(spacing: 16) {
                    Text("How many pages did you read?").font(.headline).multilineTextAlignment(.center)
                    TextField("0", text: $viewModel.pagesReadText)
                        .keyboardType(.numberPad)
                        .focused($isPagesFieldFocused)
                        .multilineTextAlignment(.center)
                        .font(.system(.largeTitle, design: .serif)).monospacedDigit()
                        .padding(.vertical, 20)
                        .background(ReadingStyle.surface, in: .rect(cornerRadius: 18))
                        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(isPagesFieldFocused ? ReadingStyle.accent : ReadingStyle.line, lineWidth: 1) }
                        .accessibilityLabel("Pages read")
                    if let message = viewModel.pagesLimitMessage {
                        Text(message).foregroundStyle(.red)
                    } else if let pages = viewModel.pagesReadValue, pages < 0 {
                        Text("Enter zero or more pages.").foregroundStyle(.red)
                    } else if let projectedPage = viewModel.projectedPage {
                        Text("Progress will move to page \(projectedPage).")
                            .foregroundStyle(ReadingStyle.secondary)
                    } else {
                        Text("You can save your time even if you read zero pages.")
                            .foregroundStyle(ReadingStyle.secondary)
                    }
                }
                .font(.footnote).multilineTextAlignment(.center)
            }
            .padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .readingBackground()
        .navigationTitle("Finish Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isPagesFieldFocused = false }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                Button { viewModel.save() } label: { Label("Save Session", systemImage: "checkmark") }
                    .buttonStyle(ReadingButtonStyle()).disabled(!viewModel.canSave)
                Button("Discard session", role: .destructive) { isConfirmingDiscard = true }
                    .font(.footnote).frame(minHeight: 44)
            }
            .padding(.horizontal, 24).padding(.top, 12)
            .frame(maxWidth: 600).frame(maxWidth: .infinity)
            .background(ReadingStyle.background)
        }
        .confirmationDialog("Discard this session?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { navigator.dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("The elapsed time will not be recorded.") }
    }
}

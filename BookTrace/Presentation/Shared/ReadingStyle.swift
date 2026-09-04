import SwiftUI
import Models

/// A quiet palette inspired by paper, book cloth and printed ink.
/// Asset colors adapt to the system appearance.
enum ReadingStyle {
    static let background = Color("Paper")
    static let surface = Color("Page")
    static let ink = Color("Ink")
    static let secondary = Color("SecondaryInk")
    static let accent = Color("AccentColor")
    static let sage = Color("Sage")
    static let line = Color("Rule")
    static let gold = Color("Ochre")

    static func title(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .serif, weight: .regular)
    }
}

extension View {
    func readingBackground() -> some View {
        self
            .foregroundStyle(ReadingStyle.ink)
            .background(ReadingStyle.background.ignoresSafeArea())
            .tint(ReadingStyle.accent)
            .toolbarBackground(ReadingStyle.background, for: .navigationBar)
    }

    func readingCard(padding: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ReadingStyle.surface, in: .rect(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(ReadingStyle.line, lineWidth: 0.7)
            }
    }
}

struct ReadingButtonStyle: ButtonStyle {
    var prominent = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 24)
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .foregroundStyle(prominent ? ReadingStyle.background : ReadingStyle.accent)
            .background(prominent ? ReadingStyle.accent : ReadingStyle.sage, in: .capsule)
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
            .contentShape(.capsule)
    }
}

struct ReadingEyebrow: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .tracking(2.2)
            .foregroundStyle(ReadingStyle.secondary)
    }
}

struct ReadingPageHeader: View {
    let eyebrow: LocalizedStringKey
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ReadingEyebrow(title: eyebrow)
            Text(title)
                .font(ReadingStyle.title())
                .foregroundStyle(ReadingStyle.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(ReadingStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ReadingSectionHeading: View {
    let title: LocalizedStringKey
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(ReadingStyle.title(.title2))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 12)
            if let detail {
                Text(detail)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ReadingStyle.secondary)
            }
        }
    }
}

struct ReadingSearchField: View {
    @Binding var text: String
    let prompt: LocalizedStringKey
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ReadingStyle.secondary)
                .accessibilityHidden(true)
            TextField(prompt, text: $text)
                .font(.subheadline)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .focused($focused)
                .onSubmit { focused = false }
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 32, height: 44)
                }
                .foregroundStyle(ReadingStyle.secondary)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, text.isEmpty ? 16 : 4)
        .frame(minHeight: 52)
        .background(ReadingStyle.surface, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(focused ? ReadingStyle.accent : ReadingStyle.line, lineWidth: 1)
        }
    }
}

struct ReadingFilterChip: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    var count: Int? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                if let count { Text(count, format: .number) }
            }
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .padding(.horizontal, 17)
            .frame(minHeight: 44)
            .foregroundStyle(isSelected ? ReadingStyle.background : ReadingStyle.secondary)
            .background(isSelected ? ReadingStyle.accent : ReadingStyle.surface, in: .capsule)
            .overlay { Capsule().strokeBorder(isSelected ? Color.clear : ReadingStyle.line, lineWidth: 0.7) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

struct ReadingEmptyState: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let actionTitle: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: symbol)
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(ReadingStyle.accent)
                .frame(width: 100, height: 100)
                .background(ReadingStyle.sage, in: .circle)
                .accessibilityHidden(true)
            VStack(spacing: 12) {
                Text(title)
                    .font(ReadingStyle.title(.title))
                    .foregroundStyle(ReadingStyle.ink)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(ReadingStyle.secondary)
                    .lineSpacing(4)
            }
            .multilineTextAlignment(.center)
            Button(actionTitle, action: action)
                .buttonStyle(ReadingButtonStyle())
        }
        .padding(.vertical, 32)
        .readingCard(padding: 28)
    }
}

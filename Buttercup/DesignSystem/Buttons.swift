import SwiftUI

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                Capsule()
                    .fill(Color("TextPrimary").opacity(configuration.isPressed ? 0.06 : 0))
                    .allowsHitTesting(false)
            }
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }

    var kind: Kind = .primary
    var height: CGFloat = 52
    var sticker = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let primary = kind == .primary
        let pressed = configuration.isPressed
        configuration.label
            .font(.headline)
            .foregroundStyle(Color(primary ? "OnAccent" : "TextPrimary"))
            .padding(.horizontal, 20)
            .frame(minWidth: 84, minHeight: height)
            .background {
                Capsule()
                    .fill(Color(primary ? "Accent" : "Surface"))
                    .overlay {
                        Capsule().fill(Color(primary ? "OnAccent" : "TextPrimary").opacity(pressed ? (primary ? 0.12 : 0.06) : 0))
                    }
            }
            .overlay(Capsule().strokeBorder(Color("Outline"), lineWidth: 2.5))
            .background {
                if sticker && isEnabled {
                    Capsule()
                        .fill(Color("Outline"))
                        .offset(x: pressed ? 0 : 3, y: pressed ? 0 : 3)
                }
            }
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.easeOut(duration: 0.1), value: pressed)
    }
}

struct IconCircleButton: View {
    enum Style { case plain, accent }

    let symbol: String
    let label: String
    var style: Style = .plain
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(style == .plain ? "TextPrimary" : "OnAccent"))
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color(style == .plain ? "Background" : "Accent")))
                .overlay(Circle().strokeBorder(Color("Outline"), lineWidth: style == .plain ? 2 : 2.5))
                .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(label)
    }
}

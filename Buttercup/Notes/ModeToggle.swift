import SwiftUI

struct ModeToggle: View {
    let mode: NoteMode
    let onRequestChange: (NoteMode) -> Void

    var body: some View {
        HStack(spacing: 0) {
            segment(.draw, symbol: "pencil.tip", label: "Draw")
            segment(.photo, symbol: "camera", label: "Photo")
        }
        .padding(.horizontal, 4)
        .background(Capsule().fill(Color("Surface")))
        .overlay(Capsule().strokeBorder(Color("Outline"), lineWidth: 2))
        .animation(.easeOut(duration: 0.15), value: mode)
    }

    private func segment(_ value: NoteMode, symbol: String, label: String) -> some View {
        let selected = value == mode
        return Button {
            if !selected { onRequestChange(value) }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 21))
                .foregroundStyle(Color(selected ? "TextPrimary" : "TextSecondary"))
                .frame(width: 46, height: 36)
                .background(Capsule().fill(Color("Divider")).opacity(selected ? 1 : 0))
                .frame(height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

import SwiftUI

struct RetakeButton: View {
    let hasPhoto: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 18, weight: .bold))
                Text("Retake")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(Color(hasPhoto ? "OnDanger" : "TextSecondary"))
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .frame(height: 40)
            .background(Capsule().fill(Color(hasPhoto ? "Danger" : "Divider")))
            .overlay(Capsule().strokeBorder(Color("Outline"), lineWidth: 2).opacity(hasPhoto ? 1 : 0))
        }
        .buttonStyle(PressableButtonStyle())
        .frame(height: 44)
        .contentShape(Rectangle())
        .disabled(!hasPhoto)
        .animation(.easeOut(duration: 0.15), value: hasPhoto)
        .accessibilityLabel("Retake photo")
    }
}

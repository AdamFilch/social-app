import SwiftUI

struct CameraRow: View {
    @Binding var flash: Bool
    @Binding var front: Bool
    let onShutter: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 56) {
            IconCircleButton(symbol: flash && !front ? "bolt" : "bolt.slash", label: "Flash") { flash.toggle() }
                .disabled(front)
                .accessibilityValue(flash && !front ? "On" : "Off")
            Button(action: onShutter) {
                Circle()
                    .fill(Color("Accent"))
                    .overlay(Circle().strokeBorder(Color("Outline"), lineWidth: 2.5))
                    .frame(width: 62, height: 62)
                    .frame(width: 76, height: 76)
                    .overlay(Circle().strokeBorder(Color("Outline"), lineWidth: 3))
                    .contentShape(Circle())
            }
            .buttonStyle(PressableButtonStyle())
            .opacity(isEnabled ? 1 : 0.4)
            .accessibilityLabel("Take photo")
            IconCircleButton(symbol: "arrow.triangle.2.circlepath.camera", label: "Switch camera") { front.toggle() }
                .accessibilityValue(front ? "Front" : "Back")
        }
    }
}

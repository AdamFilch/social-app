import SwiftUI

struct EffectsPanel: View {
    @Environment(StickerLayer.self) private var stickers
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let height: CGFloat
    let faceAllowed: Bool
    let onClose: () -> Void
    let onAdd: (Sticker.Kind) -> Void
    @State private var text = ""
    @State private var colour = InkColour.ink
    @State private var drag: CGFloat = 0
    @State private var padOpen = false
    @State private var drawn: CIImage?
    @FocusState private var focused: Bool

    private var reason: String? {
        faceAllowed ? stickers.blockedReason : "Stickers come back when your camera's on"
    }

    var body: some View {
        @Bindable var stickers = stickers
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Capsule()
                    .fill(Color("TextSecondary").opacity(0.45))
                    .frame(width: 36, height: 5)
                    .padding(.top, 7)
                HStack(spacing: 0) {
                    IconCircleButton(symbol: "xmark", label: "Close stickers", action: onClose)
                    PillTabRow(
                        tabs: EffectTab.allCases,
                        selection: $stickers.tab,
                        disabled: faceAllowed ? [] : Set(EffectTab.allCases),
                        title: \.title
                    )
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Effects")
                    .accessibilityAddTraits(.isHeader)
                }
                .padding(.leading, 16)
                .frame(height: 44)
            }
            .contentShape(Rectangle())
            .gesture(swipeDown)
            content
                .padding(.top, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .animation(.easeOut(duration: 0.15), value: stickers.tab)
        }
        .frame(height: focused ? 292 : height, alignment: .top)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                .fill(Color("Surface"))
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .offset(y: drag)
        .animation(.easeOut(duration: 0.25), value: focused)
        .accessibilityAction(.escape, onClose)
    }

    @ViewBuilder private var content: some View {
        let blocked = !faceAllowed || stickers.blocked
        switch stickers.tab {
        case .stickers:
            if Stickers.names.isEmpty {
                Text("No stickers yet.")
                    .foregroundStyle(Color("TextSecondary"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    StickerGrid(names: Stickers.names, hint: "Double-tap to add to your face") { onAdd(.image($0)) }
                        .disabled(blocked)
                        .opacity(blocked ? 0.4 : 1)
                    line(reason ?? "Drag one onto your face")
                }
                .transition(.opacity)
            }
        case .emoji:
            EmojiStrip(categories: Emoji.categories, hint: "Double-tap to add. Actions for skin tone", footer: reason) { onAdd(.emoji($0)) }
                .padding(.top, -4)
                .transition(.opacity)
        case .text:
            VStack(spacing: 12) {
                TextStickerComposer(
                    text: $text,
                    colour: $colour,
                    font: .constant(.rounded),
                    focus: $focused,
                    colours: Sticker.textColours,
                    onAdd: addText
                )
                .disabled(blocked)
                .opacity(blocked ? 0.4 : 1)
                if let reason { line(reason) }
            }
            .onAppear { if !blocked { focused = true } }
            .transition(.opacity)
        case .draw:
            VStack(spacing: 12) {
                Button("Open drawing pad") { padOpen = true }
                    .buttonStyle(PillButtonStyle())
                    .padding(.horizontal, 16)
                    .disabled(blocked)
                line(reason ?? "Draw something, then drag it onto your face")
            }
            .transition(.opacity)
            .sheet(isPresented: $padOpen, onDismiss: addDrawing) {
                DrawingPad { drawn = $0 }
            }
        }
    }

    private func line(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color("TextSecondary"))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
    }

    private func addText() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        focused = false
        onAdd(.text(trimmed, colour))
    }

    private func addDrawing() {
        guard let drawn else { return }
        self.drawn = nil
        onAdd(.drawing(drawn))
    }

    private var swipeDown: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if !reduceMotion { drag = max(0, value.translation.height) }
            }
            .onEnded { value in
                if value.translation.height > height * 0.3 || value.velocity.height > 600 {
                    onClose()
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { drag = 0 }
                }
            }
    }
}

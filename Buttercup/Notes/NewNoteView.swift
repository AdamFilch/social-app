import SwiftUI

enum NoteTab: CaseIterable {
    case draw, stickers, emoji, text, face

    var title: String {
        switch self {
        case .draw: "Draw"
        case .stickers: "Stickers"
        case .emoji: "Emoji"
        case .text: "Text"
        case .face: "Face"
        }
    }
}

struct NewNoteView: View {
    let partnerName: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft = NoteDraft()
    @State private var tab: NoteTab = .draw
    @State private var tool: DrawTool = .pen
    @State private var colour: InkColour = .ink
    @State private var pendingDiscard: (() -> Void)?
    @State private var dragOffset: CGFloat = 0
    @State private var height: CGFloat = 896

    var body: some View {
        VStack(spacing: 0) {
            topBand
                .padding(.top, 8)
            NoteCanvas(draft: draft, tool: tool, colour: colour, partnerName: partnerName)
                .padding(.horizontal, 8)
                .padding(.top, 8)
            if draft.mode == .draw {
                PillTabRow(
                    tabs: NoteTab.allCases,
                    selection: $tab,
                    disabled: [.face],
                    title: \.title,
                    accessibilityLabel: { $0 == .face ? "Face stickers, coming later" : $0.title }
                )
                .padding(.top, 16)
                .transition(.opacity)
                if tab == .draw {
                    drawPanel
                        .padding(.top, 16)
                        .transition(.opacity)
                }
                if tab == .stickers {
                    stickersPanel
                        .padding(.top, 14)
                        .transition(.opacity)
                }
            }
            Spacer(minLength: 0)
        }
        .animation(.easeOut(duration: 0.15), value: tab)
        .sensoryFeedback(.impact(weight: .light), trigger: draft.items.count) { old, new in new > old }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background"))
        .fontDesign(.rounded)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .offset(y: dragOffset)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .presentationBackground(.clear)
        .accessibilityAction(.escape) { confirm { dismiss() } }
        .alert("Discard this note?", isPresented: Binding(get: { pendingDiscard != nil }, set: { if !$0 { pendingDiscard = nil } })) {
            Button("Keep editing", role: .cancel) {}
            Button("Discard", role: .destructive) { pendingDiscard?() }
        } message: {
            Text("You will lose your progress if you proceed")
        }
    }

    private var topBand: some View {
        VStack(spacing: 8) {
            HStack {
                IconCircleButton(symbol: "xmark", label: "Close") { confirm { dismiss() } }
                Spacer()
                Button("Send") {}
                    .buttonStyle(PillButtonStyle(height: 44, sticker: true))
                    .disabled(true)
                    .accessibilityLabel("Send to \(partnerName)")
                    .accessibilityHint("Draw or add something first")
                    .padding(.trailing, 3)
            }
            .frame(height: 44)
            HStack {
                Spacer()
                ModeToggle(mode: draft.mode) { mode in
                    confirm {
                        withAnimation(.easeOut(duration: 0.2)) { draft.reset(to: mode) }
                    }
                }
            }
            .frame(height: 44)
        }
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .gesture(swipeDown)
    }

    private var drawPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            DrawTools(tool: $tool, canUndo: !draft.history.isEmpty) { draft.undo() }
                .padding(.horizontal, 16)
            ColourDots(
                colours: InkColour.allCases,
                selection: Binding(get: { colour }, set: { colour = $0; tool = .pen }),
                layout: .grid(rows: 2),
                colour: \.color,
                name: \.name
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var stickersPanel: some View {
        if Stickers.names.isEmpty {
            Text("No stickers yet.")
                .font(.body)
                .foregroundStyle(Color("TextSecondary"))
                .frame(maxWidth: .infinity, minHeight: 176)
        } else {
            VStack(spacing: 12) {
                StickerGrid(names: Stickers.names, rows: 2, cellFill: Color("Surface")) { name in
                    withAnimation(.easeOut(duration: 0.15)) {
                        draft.add(.sticker(name), at: CGPoint(x: 0.5, y: 0.5), select: true)
                    }
                }
                Text("Tap one, or drag it onto the note")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color("TextSecondary"))
            }
        }
    }

    private var swipeDown: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !reduceMotion else { return }
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                let shouldClose = value.translation.height > height * 0.3 || value.velocity.height > 600
                if shouldClose && !draft.hasProgress {
                    dismiss()
                    return
                }
                withAnimation(.easeOut(duration: 0.2)) { dragOffset = 0 }
                if shouldClose { confirm { dismiss() } }
            }
    }

    private func confirm(_ action: @escaping () -> Void) {
        if draft.hasProgress {
            pendingDiscard = action
        } else {
            action()
        }
    }
}

#Preview {
    NewNoteView(partnerName: "Sam")
}

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
    @State private var pendingDiscard: (() -> Void)?
    @State private var dragOffset: CGFloat = 0
    @State private var height: CGFloat = 896

    var body: some View {
        VStack(spacing: 0) {
            topBand
                .padding(.top, 8)
            canvas
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
            }
            Spacer(minLength: 0)
        }
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

    private var canvas: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(draft.mode == .draw ? Color.white : Color("Surface"))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color("Outline"), lineWidth: 2.5))
            .aspectRatio(1, contentMode: .fit)
            .accessibilityElement()
            .accessibilityLabel("Note")
            .accessibilityValue(draft.hasProgress ? "" : "Empty")
        #if DEBUG
            .onTapGesture(count: 3) { draft.items.append(NoteItem()) }
        #endif
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

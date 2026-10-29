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
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("noteCameraFront") private var front = false
    @State private var camera = Camera()
    @State private var flash = false
    @State private var draft = NoteDraft()
    @State private var tab: NoteTab = .draw
    @State private var tool: DrawTool = .pen
    @State private var colour: InkColour = .ink
    @State private var pendingDiscard: (() -> Void)?
    @State private var dragOffset: CGFloat = 0
    @State private var height: CGFloat = 896
    @State private var noteText = ""
    @State private var textColour: InkColour = .ink
    @State private var noteFont: NoteFont = .rounded
    @FocusState private var textFocused: Bool
    @State private var canvasFrame: CGRect = .zero
    @State private var toolsRest: CGFloat = .infinity
    @State private var raisedTop: CGFloat?

    private static let toolsHeight: CGFloat = 136

    var body: some View {
        ZStack(alignment: .top) {
            content
                .ignoresSafeArea(.keyboard)
            if editing && tab == .text {
                GeometryReader { geo in
                    let top = min(toolsRest, geo.size.height - Self.toolsHeight)
                    textTools(raised: top < toolsRest)
                        .offset(y: top)
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    let top = height - Self.toolsHeight
                    if top < toolsRest { raisedTop = top } else if !textFocused { raisedTop = nil }
                }
                .transition(.opacity)
            }
        }
        .coordinateSpace(.named("note"))
        .onChange(of: tab) { _, new in
            if new != .text { noteText = "" }
        }
        .onChange(of: textFocused) { _, focused in
            if !focused { raisedTop = nil }
        }
        .animation(.easeOut(duration: 0.15), value: tab)
        .task(id: [draft.mode == .photo && draft.photo == nil, front, scenePhase == .active]) {
            if draft.mode == .photo && draft.photo == nil && scenePhase == .active {
                await camera.start(front: front)
            } else {
                camera.stop()
            }
        }
        .onDisappear { camera.stop() }
        .sensoryFeedback(.impact(weight: .light), trigger: draft.items.count) { old, new in new > old }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background"))
        .fontDesign(.rounded)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .offset(y: dragOffset)
        .presentationBackground(.clear)
        .accessibilityAction(.escape) { confirm { dismiss() } }
        .alert("Discard this note?", isPresented: Binding(get: { pendingDiscard != nil }, set: { if !$0 { pendingDiscard = nil } })) {
            Button("Keep editing", role: .cancel) {}
            Button("Discard", role: .destructive) { pendingDiscard?() }
        } message: {
            Text("You will lose your progress if you proceed")
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            topBand
                .padding(.top, 8)
            NoteCanvas(draft: draft, tool: tool, colour: colour, partnerName: partnerName, camera: camera, preview: textPreview)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("note")) } action: { canvasFrame = $0 }
                .overlay {
                    if textFocused {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { textFocused = false }
                            .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
            if !editing {
                CameraRow(flash: $flash, front: $front, onShutter: capture)
                    .disabled(camera.status != .ready)
                    .padding(.top, 96)
                    .transition(.opacity)
            }
            if editing {
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
                if tab == .emoji {
                    EmojiStrip(categories: Emoji.categories, rows: 2) { emoji in
                        withAnimation(.easeOut(duration: 0.15)) {
                            draft.add(.emoji(emoji), at: CGPoint(x: 0.5, y: 0.5), select: true)
                        }
                    }
                    .padding(.top, 4)
                    .transition(.opacity)
                }
                if tab == .text {
                    Color.clear
                        .frame(height: Self.toolsHeight)
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("note")).minY } action: { toolsRest = $0 }
                }
            }
            Spacer(minLength: 0)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
    }

    private var editing: Bool { draft.mode == .draw || draft.photo != nil }

    private func capture() {
        camera.capture(flash: flash && !front) { image in
            withAnimation(.easeOut(duration: 0.15)) {
                tab = .draw
                draft.photo = image
            }
        }
    }

    private func retake() {
        let clear = { withAnimation(.easeOut(duration: 0.15)) { draft.reset(to: .photo) } }
        if draft.drawing.strokes.isEmpty && draft.items.isEmpty {
            clear()
        } else {
            pendingDiscard = clear
        }
    }

    private var trimmedText: String { noteText.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var previewY: CGFloat {
        guard canvasFrame.height > 0 else { return 0.5 }
        let visibleBottom = min(canvasFrame.maxY, raisedTop ?? toolsRest)
        return (visibleBottom - canvasFrame.minY) / 2 / canvasFrame.height
    }

    private var textPreview: NoteItem? {
        guard tab == .text, !trimmedText.isEmpty else { return nil }
        return NoteItem(kind: .text(trimmedText, noteFont, textColour.color), center: CGPoint(x: 0.5, y: previewY))
    }

    private func textTools(raised: Bool) -> some View {
        TextStickerComposer(
            text: $noteText,
            colour: $textColour,
            font: $noteFont,
            focus: $textFocused,
            colours: InkColour.allCases,
            fonts: NoteFont.allCases,
            addHasShadow: false,
            preview: .external,
            onAdd: addText
        )
        .padding(.top, 4)
        .frame(height: Self.toolsHeight, alignment: .top)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                .fill(Color("Surface"))
                .opacity(raised ? 1 : 0)
        }
        .onAppear { textFocused = true }
    }

    private func addText() {
        guard let preview = textPreview else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            draft.add(preview.kind, at: preview.center, select: true)
        }
        noteText = ""
        textFocused = false
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
                if draft.mode == .photo {
                    RetakeButton(hasPhoto: draft.photo != nil, action: retake)
                        .transition(.opacity)
                }
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

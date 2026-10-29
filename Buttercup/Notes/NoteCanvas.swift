import PencilKit
import SwiftUI

struct NoteCanvas: View {
    @Bindable var draft: NoteDraft
    let tool: DrawTool
    let colour: InkColour
    let partnerName: String
    let camera: Camera
    var preview: NoteItem?

    private var editing: Bool { draft.mode == .draw || draft.photo != nil }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        GeometryReader { geo in
            let side = geo.size.width
            ZStack {
                ZStack {
                    shape.fill(draft.mode == .draw ? Color.white : Color("Surface"))
                    if let photo = draft.photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                    }
                    if draft.mode == .draw {
                        hint
                            .opacity(draft.hasProgress || preview != nil ? 0 : 1)
                            .animation(.easeOut(duration: 0.15), value: draft.hasProgress || preview != nil)
                    }
                    if editing {
                        DrawingView(draft: draft, tool: tool, colour: colour, isLocked: draft.selection != nil)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel("Note")
                .accessibilityValue(contentSummary)
                .accessibilityHint(editing && tool == .pen ? "Draw with one finger" : "")
                if !editing {
                    viewfinder
                        .transition(.opacity)
                }
                if draft.selection != nil {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { draft.selection = nil }
                        .accessibilityHidden(true)
                }
                ForEach($draft.items) { $item in
                    NoteItemView(
                        item: $item,
                        side: side,
                        isSelected: draft.selection == item.id,
                        onSelect: { draft.selection = item.id },
                        onMove: { draft.bringToFront(item.id) },
                        onRemove: { withAnimation(.easeOut(duration: 0.15)) { draft.remove(item.id) } }
                    )
                    .transition(.opacity)
                }
                .accessibilitySortPriority(1)
                if let preview, case .text(let text, let font, let colour) = preview.kind {
                    TextSticker(text: text, font: font, colour: colour, size: side * NoteItem.textSize)
                        .position(x: preview.center.x * side, y: preview.center.y * side)
                        .allowsHitTesting(false)
                }
            }
            .dropDestination(for: String.self) { values, location in
                guard let value = values.first else { return false }
                let kind: NoteItem.Kind
                if Stickers.names.contains(value) {
                    kind = .sticker(value)
                } else if Emoji.names[value] != nil {
                    kind = .emoji(value)
                } else {
                    return false
                }
                withAnimation(.easeOut(duration: 0.15)) {
                    draft.add(kind, at: CGPoint(x: location.x / side, y: location.y / side), select: false)
                }
                return true
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color("Outline"), lineWidth: 2.5).allowsHitTesting(false))
        .aspectRatio(1, contentMode: .fit)
    }

    private var contentSummary: String {
        var parts: [String] = []
        if !draft.items.isEmpty { parts.append(draft.items.count == 1 ? "1 sticker" : "\(draft.items.count) stickers") }
        if !draft.drawing.strokes.isEmpty { parts.append("drawing") }
        let joined = parts.joined(separator: " and ")
        if draft.photo != nil { return joined.isEmpty ? "Photo" : "Photo with \(joined)" }
        guard !parts.isEmpty else { return "Empty" }
        let summary = joined
        return summary.prefix(1).uppercased() + summary.dropFirst()
    }

    @ViewBuilder
    private var viewfinder: some View {
        switch camera.status {
        case .ready: CameraView(camera: camera)
        case .denied: CameraBlockedView(reason: .denied, partnerName: partnerName)
        case .unavailable: CameraBlockedView(reason: .unavailable, partnerName: partnerName)
        case .unknown: Color.clear
        }
    }

    private var hint: some View {
        Text("Draw something for \(partnerName)")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color("TextSecondary"))
            .padding(.vertical, 4)
            .padding(.horizontal, 14)
            .background(Capsule().fill(Color("Background")))
            .environment(\.colorScheme, .light)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct DrawingView: UIViewRepresentable {
    let draft: NoteDraft
    let tool: DrawTool
    let colour: InkColour
    let isLocked: Bool

    func makeCoordinator() -> Coordinator { Coordinator(draft: draft) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.overrideUserInterfaceStyle = .light
        canvas.drawing = draft.drawing
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.draft = draft
        canvas.isUserInteractionEnabled = !isLocked
        canvas.tool = tool == .pen ? PKInkingTool(.monoline, color: colour.uiColor, width: 4.5) : PKEraserTool(.vector)
        if canvas.drawing != draft.drawing {
            canvas.drawing = draft.drawing
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var draft: NoteDraft

        init(draft: NoteDraft) { self.draft = draft }

        func canvasViewDrawingDidChange(_ canvas: PKCanvasView) {
            guard canvas.drawing != draft.drawing else { return }
            draft.history.append(PKDrawing(strokes: draft.drawing.strokes))
            draft.drawing = canvas.drawing
        }
    }
}

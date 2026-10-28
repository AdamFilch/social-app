import PencilKit
import SwiftUI

struct NoteCanvas: View {
    let draft: NoteDraft
    let tool: DrawTool
    let colour: InkColour
    let partnerName: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        ZStack {
            shape.fill(draft.mode == .draw ? Color.white : Color("Surface"))
            if draft.mode == .draw {
                DrawingView(draft: draft, tool: tool, colour: colour)
                hint
                    .opacity(draft.hasProgress ? 0 : 1)
                    .animation(.easeOut(duration: 0.15), value: draft.hasProgress)
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color("Outline"), lineWidth: 2.5).allowsHitTesting(false))
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Note")
        .accessibilityValue(draft.hasProgress ? "Drawing" : "Empty")
        .accessibilityHint(draft.mode == .draw && tool == .pen ? "Draw with one finger" : "")
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

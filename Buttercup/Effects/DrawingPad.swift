import CoreImage
import PencilKit
import SwiftUI

struct DrawingPad: View {
    let onDone: (CIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var drawing = PKDrawing()

    var body: some View {
        NavigationStack {
            PadCanvas(drawing: $drawing)
                .background(Checkerboard().environment(\.colorScheme, .light))
                .ignoresSafeArea(.container, edges: .bottom)
                .navigationTitle("Draw")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: done)
                            .disabled(drawing.strokes.isEmpty)
                            .accessibilityHint(drawing.strokes.isEmpty ? "Draw something first" : "")
                    }
                }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled()
    }

    private func done() {
        var image: UIImage?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = drawing.image(from: drawing.bounds, scale: 2)
        }
        if let cgImage = image?.cgImage { onDone(CIImage(cgImage: cgImage)) }
        dismiss()
    }
}

private struct PadCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeCoordinator() -> Coordinator { Coordinator(drawing: $drawing) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.overrideUserInterfaceStyle = .light
        canvas.delegate = context.coordinator
        context.coordinator.picker.colorUserInterfaceStyle = .light
        context.coordinator.picker.setVisible(true, forFirstResponder: canvas)
        context.coordinator.picker.addObserver(canvas)
        DispatchQueue.main.async { canvas.becomeFirstResponder() }
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {}

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let picker = PKToolPicker()
        var drawing: Binding<PKDrawing>

        init(drawing: Binding<PKDrawing>) { self.drawing = drawing }

        func canvasViewDrawingDidChange(_ canvas: PKCanvasView) {
            drawing.wrappedValue = canvas.drawing
        }
    }
}

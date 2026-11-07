import CoreImage
import PencilKit
import SwiftUI

struct DrawingPad: View {
    @Binding var drawing: PKDrawing
    @State private var pickerTop = CGFloat.infinity

    var body: some View {
        GeometryReader { geo in
            let covered = max(0, geo.frame(in: .global).maxY - pickerTop)
            PadCanvas(drawing: $drawing, pickerTop: $pickerTop)
                .background(Checkerboard().environment(\.colorScheme, .light))
                .overlay {
                    if drawing.strokes.isEmpty {
                        Text("Draw something to wear")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color("TextSecondary"))
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                            .background(Capsule().fill(Color("Surface")))
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.15), value: drawing.strokes.isEmpty)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color("Outline"), lineWidth: 2))
                .padding(.horizontal, 16)
                .padding(.bottom, covered > 0 ? covered + 12 : 16)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Drawing canvas")
    }

    static func image(of drawing: PKDrawing) -> CIImage? {
        var image: UIImage?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = drawing.image(from: drawing.bounds, scale: 2)
        }
        return image?.cgImage.map { CIImage(cgImage: $0) }
    }
}

private struct PadCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    @Binding var pickerTop: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(drawing: $drawing, pickerTop: $pickerTop) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.overrideUserInterfaceStyle = .light
        canvas.delegate = context.coordinator
        context.coordinator.canvas = canvas
        let picker = context.coordinator.picker
        picker.colorUserInterfaceStyle = .light
        picker.setVisible(true, forFirstResponder: canvas)
        picker.addObserver(canvas)
        picker.addObserver(context.coordinator)
        DispatchQueue.main.async { canvas.becomeFirstResponder() }
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {}

    final class Coordinator: NSObject, PKCanvasViewDelegate, PKToolPickerObserver {
        let picker = PKToolPicker()
        weak var canvas: PKCanvasView?
        var drawing: Binding<PKDrawing>
        var pickerTop: Binding<CGFloat>

        init(drawing: Binding<PKDrawing>, pickerTop: Binding<CGFloat>) {
            self.drawing = drawing
            self.pickerTop = pickerTop
        }

        func canvasViewDrawingDidChange(_ canvas: PKCanvasView) {
            drawing.wrappedValue = canvas.drawing
        }

        func toolPickerFramesObscuredDidChange(_ toolPicker: PKToolPicker) { measure(toolPicker) }

        func toolPickerVisibilityDidChange(_ toolPicker: PKToolPicker) { measure(toolPicker) }

        private func measure(_ toolPicker: PKToolPicker) {
            guard let window = canvas?.window else { return }
            let frame = toolPicker.frameObscured(in: window)
            pickerTop.wrappedValue = toolPicker.isVisible && !frame.isNull ? frame.minY : .infinity
        }
    }
}

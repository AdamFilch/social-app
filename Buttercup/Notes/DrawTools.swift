import SwiftUI

enum DrawTool {
    case pen, eraser
}

enum InkColour: String, CaseIterable {
    case ink, buttercup, yellow, pink, blue, green, lilac, red, orange, white

    var name: String { rawValue.capitalized }

    var uiColor: UIColor {
        let asset: String? = switch self {
        case .ink: "TextPrimary"
        case .buttercup: "Accent"
        case .yellow: "NotePaperYellow"
        case .pink: "NotePaperPink"
        case .blue: "NotePaperBlue"
        case .green: "NotePaperGreen"
        case .lilac: "NotePaperLilac"
        case .red: "NoteInkRed"
        case .orange: "NoteInkOrange"
        case .white: nil
        }
        guard let asset, let color = UIColor(named: asset) else { return .white }
        return color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
    }

    var color: Color { Color(uiColor: uiColor) }
}

struct DrawTools: View {
    @Binding var tool: DrawTool
    let canUndo: Bool
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            toolButton(.pen, symbol: "pencil.tip", label: "Pen")
            toolButton(.eraser, symbol: "eraser", label: "Eraser")
            Button(action: onUndo) {
                circle(symbol: "arrow.uturn.backward", selected: false)
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!canUndo)
            .opacity(canUndo ? 1 : 0.4)
            .accessibilityLabel("Undo")
        }
    }

    private func toolButton(_ value: DrawTool, symbol: String, label: String) -> some View {
        let selected = value == tool
        return Button {
            tool = value
        } label: {
            circle(symbol: symbol, selected: selected)
        }
        .buttonStyle(PressableButtonStyle())
        .animation(.easeOut(duration: 0.15), value: selected)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func circle(symbol: String, selected: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 22))
            .foregroundStyle(Color(selected ? "OnAccent" : "TextPrimary"))
            .frame(width: 44, height: 44)
            .background(Circle().fill(selected ? Color("Accent") : .clear))
            .overlay(Circle().strokeBorder(Color("Outline"), lineWidth: 2).opacity(selected ? 1 : 0))
            .contentShape(Circle())
    }
}

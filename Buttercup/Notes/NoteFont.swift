import SwiftUI

enum NoteFont: CaseIterable {
    case rounded, serif, handwritten, mono

    var title: String {
        switch self {
        case .rounded: "Rounded"
        case .serif: "Serif"
        case .handwritten: "Handwritten"
        case .mono: "Mono"
        }
    }

    var labelSize: CGFloat {
        switch self {
        case .handwritten: 18
        case .mono: 14
        default: 16
        }
    }

    func font(size: CGFloat) -> Font {
        switch self {
        case .rounded: .system(size: size, weight: .heavy, design: .rounded)
        case .serif: .system(size: size, weight: .bold, design: .serif)
        case .handwritten: .custom("Noteworthy-Bold", fixedSize: size)
        case .mono: .system(size: size, weight: .bold, design: .monospaced)
        }
    }
}

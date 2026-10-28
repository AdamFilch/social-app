import SwiftUI

struct NoteItem: Identifiable {
    enum Kind {
        case sticker(String)
        case emoji(String)
        case text(String, NoteFont, Color)

        var label: String {
            switch self {
            case .sticker(let name): "\(Stickers.label(name)) sticker"
            case .emoji(let emoji): Emoji.names[emoji] ?? emoji
            case .text(let text, _, _): text
            }
        }
    }

    static let baseSize: CGFloat = 0.3
    static let textSize: CGFloat = 52.0 / 398
    static let scaleRange: ClosedRange<CGFloat> = 0.3...4

    let id = UUID()
    let kind: Kind
    var center: CGPoint
    var scale: CGFloat = 1
    var rotation: Angle = .zero

    static func clampScale(_ value: CGFloat) -> CGFloat {
        min(max(value, scaleRange.lowerBound), scaleRange.upperBound)
    }

    static func clampCenter(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.x, 0), 1), y: min(max(point.y, 0), 1))
    }
}

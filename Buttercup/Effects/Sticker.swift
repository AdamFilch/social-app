import CoreImage
import SwiftUI
import UIKit

enum EffectTab: CaseIterable {
    case stickers, emoji, text, draw

    var title: String {
        switch self {
        case .stickers: "Stickers"
        case .emoji: "Emoji"
        case .text: "Text"
        case .draw: "Draw"
        }
    }
}

struct Sticker: Identifiable {
    enum Kind {
        case emoji(String)
        case text(String, InkColour)
        case image(String)
        case drawing(CIImage)

        var isText: Bool {
            if case .text = self { true } else { false }
        }
    }

    let id = UUID()
    let kind: Kind

    static let textColours: [InkColour] = [.ink, .buttercup, .pink, .blue, .green, .lilac]

    static func dropped(_ payload: String) -> Kind {
        Stickers.names.contains(payload) ? .image(payload) : .emoji(payload)
    }

    static func imageURL(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "stickers")
    }

    func render() -> CIImage? {
        switch kind {
        case .image(let name):
            Self.imageURL(name).flatMap { CIImage(contentsOf: $0) }
        case .emoji(let emoji):
            Self.draw(emoji, font: .systemFont(ofSize: 360), color: .black, outline: nil)
        case .text(let text, let color):
            Self.draw(text, font: .systemFont(ofSize: 160, weight: .heavy).rounded, color: color.uiColor, outline: InkColour.ink.uiColor)
        case .drawing(let image):
            image
        }
    }

    private static func draw(_ string: String, font: UIFont, color: UIColor, outline: UIColor?) -> CIImage? {
        var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        if let outline {
            attributes[.strokeColor] = outline
            attributes[.strokeWidth] = -8
        }
        let text = NSAttributedString(string: string, attributes: attributes)
        let size = text.size()
        let pad: CGFloat = 24
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: ceil(size.width) + pad * 2, height: ceil(size.height) + pad * 2), format: format)
            .image { _ in text.draw(at: CGPoint(x: pad, y: pad)) }
        return image.cgImage.map { CIImage(cgImage: $0) }
    }
}

private extension UIFont {
    var rounded: UIFont {
        fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: pointSize) } ?? self
    }
}

enum Anchor {
    case surface(triangle: Int, weights: SIMD3<Float>)
    case plane(SIMD3<Float>)
}

struct PlacedSticker: Identifiable {
    let sticker: Sticker
    var anchor: Anchor
    var scale: Float = 1
    var rotation: Float = 0
    let image: CIImage

    var id: UUID { sticker.id }
}

@Observable @MainActor
final class StickerLayer {
    static let cap = 10

    private(set) var items: [PlacedSticker] = [] {
        didSet { compositor.items = items }
    }
    var selected: UUID?
    var tab = EffectTab.stickers
    private(set) var drops = 0
    private(set) var faceTracked = false
    private(set) var hot = ProcessInfo.processInfo.thermalState == .critical
    let compositor = StickerCompositor()

    init() {
        compositor.onTracking = { [weak self] tracked in
            Task { @MainActor in self?.faceTracked = tracked }
        }
        NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.hot = ProcessInfo.processInfo.thermalState == .critical }
        }
    }

    var full: Bool { items.count >= Self.cap }
    var blocked: Bool { full || hot || !faceTracked }

    var blockedReason: String? {
        if hot { "Stickers are paused while your phone cools down." }
        else if full { "That's 10. Remove one to add more." }
        else if !faceTracked { "Show your face to add stickers" }
        else { nil }
    }

    @discardableResult
    func add(_ sticker: Sticker, at point: CGPoint?, select: Bool = false) -> Bool {
        guard !blocked, let anchor = compositor.pin(at: point), let image = sticker.render() else { return false }
        items.append(PlacedSticker(sticker: sticker, anchor: anchor, image: image))
        if select { selected = sticker.id }
        drops += 1
        return true
    }

    func move(_ id: UUID, to point: CGPoint) {
        guard let index = items.firstIndex(where: { $0.id == id }), let anchor = compositor.pin(at: point) else { return }
        items[index].anchor = anchor
    }

    func update(_ id: UUID, _ change: (inout PlacedSticker) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        if selected == id { selected = nil }
    }

    func clear() {
        items = []
        selected = nil
    }
}

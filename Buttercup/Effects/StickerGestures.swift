import SwiftUI

struct StickerGestures: View {
    @Environment(StickerLayer.self) private var stickers
    let mirror: Bool
    @State private var dragging = false
    @State private var moving: UUID?
    @State private var target: (id: UUID, scale: Float, rotation: Float)?

    var body: some View {
        GeometryReader { geo in
            let map = { Mapping(view: geo.size, display: stickers.compositor.displaySize, mirror: mirror) }
            Color.clear
                .contentShape(Rectangle())
                .overlay { selection(map) }
                .onTapGesture { point in
                    stickers.selected = stickers.compositor.hit(map().toDisplay(point))
                }
                .gesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            if !dragging {
                                dragging = true
                                moving = stickers.compositor.hit(map().toDisplay(value.startLocation))
                            }
                            if let moving { stickers.move(moving, to: map().toDisplay(value.location)) }
                        }
                        .onEnded { _ in
                            dragging = false
                            moving = nil
                        }
                )
                .simultaneousGesture(
                    MagnifyGesture()
                        .simultaneously(with: RotateGesture())
                        .onChanged { value in
                            if target == nil {
                                let start = value.first.flatMap { stickers.compositor.hit(map().toDisplay($0.startLocation)) }
                                guard let id = start ?? stickers.selected ?? stickers.items.last?.id,
                                      let item = stickers.items.first(where: { $0.id == id }) else { return }
                                target = (id, item.scale, item.rotation)
                            }
                            guard let target else { return }
                            let scale = Float(value.first?.magnification ?? 1)
                            let turn = Float(value.second?.rotation.radians ?? 0)
                            stickers.update(target.id) {
                                $0.scale = min(max(target.scale * scale, 0.3), 5)
                                $0.rotation = target.rotation + (mirror ? turn : -turn)
                            }
                        }
                        .onEnded { _ in target = nil }
                )
                .dropDestination(for: String.self) { _, point in
                    guard let sticker = stickers.dragging else { return false }
                    stickers.dragging = nil
                    stickers.add(sticker, at: map().toDisplay(point))
                    return true
                }
        }
    }

    @ViewBuilder private func selection(_ map: @escaping () -> Mapping) -> some View {
        if let id = stickers.selected {
            TimelineView(.animation) { _ in
                if let p = stickers.compositor.placement(id) {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white, style: StrokeStyle(lineWidth: 2.5, dash: [8, 6]))
                        .frame(width: p.size.width * map().scale + 16, height: p.size.height * map().scale + 16)
                        .rotationEffect(.radians(mirror ? p.angle : -p.angle))
                        .position(map().toView(p.center))
                }
            }
            .allowsHitTesting(false)
        }
    }
}

private struct Mapping {
    let view: CGSize
    let display: CGSize
    let mirror: Bool

    var scale: CGFloat { max(view.width / display.width, view.height / display.height) }
    private var origin: CGPoint {
        CGPoint(x: (view.width - display.width * scale) / 2, y: (view.height - display.height * scale) / 2)
    }

    func toDisplay(_ point: CGPoint) -> CGPoint {
        let x = mirror ? view.width - point.x : point.x
        return CGPoint(x: (x - origin.x) / scale, y: display.height - (point.y - origin.y) / scale)
    }

    func toView(_ point: CGPoint) -> CGPoint {
        let x = point.x * scale + origin.x
        return CGPoint(x: mirror ? view.width - x : x, y: (display.height - point.y) * scale + origin.y)
    }
}

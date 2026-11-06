import SwiftUI

struct StickerGestures: View {
    @Environment(StickerLayer.self) private var stickers
    let mirror: Bool
    let panelTop: CGFloat
    @Binding var hovering: Bool
    let onDrop: () -> Void
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
                                $0.rotation = target.rotation + (mirror ? -turn : turn)
                            }
                        }
                        .onEnded { _ in target = nil }
                )
                .onDrop(of: [.plainText], delegate: TrayDrop(panelTop: panelTop, hovering: $hovering) { payload, point in
                    if let payload, stickers.add(Sticker(kind: Sticker.dropped(payload)), at: map().toDisplay(point)) {
                        onDrop()
                    } else {
                        withAnimation(.easeOut(duration: 0.25)) { hovering = false }
                    }
                })
                .accessibilityElement(children: .contain)
                .accessibilityChildren {
                    ForEach(stickers.items) { item in
                        Color.clear
                            .accessibilityLabel(label(item.sticker.kind))
                            .accessibilityAction(named: "Remove") { stickers.remove(item.id) }
                            .accessibilityAction(named: "Make bigger") { resize(item.id, by: 1.25) }
                            .accessibilityAction(named: "Make smaller") { resize(item.id, by: 0.8) }
                    }
                }
        }
    }

    @ViewBuilder private func selection(_ map: @escaping () -> Mapping) -> some View {
        if let id = stickers.selected {
            TimelineView(.animation) { _ in
                if let p = stickers.compositor.placement(id) {
                    let quad = Path { $0.addLines(p.corners.map(map().toView)); $0.closeSubpath() }
                    quad.union(quad.strokedPath(StrokeStyle(lineWidth: 16, lineJoin: .round)))
                        .stroke(Color("Accent"), lineWidth: 2.5)
                }
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    private func resize(_ id: UUID, by factor: Float) {
        stickers.update(id) { $0.scale = min(max($0.scale * factor, 0.3), 5) }
    }

    private func label(_ kind: Sticker.Kind) -> String {
        switch kind {
        case .image(let name): "\(Stickers.label(name)) sticker"
        case .emoji(let emoji): "\(Emoji.names[emoji] ?? emoji) sticker"
        case .text(let text, _): "Text sticker, \(text)"
        }
    }
}

private struct TrayDrop: DropDelegate {
    let panelTop: CGFloat
    @Binding var hovering: Bool
    let drop: @MainActor (String?, CGPoint) -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let above = info.location.y < panelTop
        if hovering != above { withAnimation(.easeOut(duration: 0.25)) { hovering = above } }
        return DropProposal(operation: above ? .copy : .cancel)
    }

    func dropExited(info _: DropInfo) {
        withAnimation(.easeOut(duration: 0.25)) { hovering = false }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard info.location.y < panelTop, let provider = info.itemProviders(for: [.plainText]).first else { return false }
        let point = info.location
        let drop = drop
        _ = provider.loadTransferable(type: String.self) { result in
            let payload = try? result.get()
            Task { @MainActor in drop(payload, point) }
        }
        return true
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

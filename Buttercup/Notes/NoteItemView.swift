import SwiftUI

struct NoteItemView: View {
    @Binding var item: NoteItem
    let side: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void
    let onMove: () -> Void
    let onRemove: () -> Void
    @GestureState private var drag: CGSize = .zero
    @GestureState private var magnification: CGFloat = 1
    @GestureState private var turn: Angle = .zero

    private var center: CGPoint {
        CGPoint(x: item.center.x * side + drag.width, y: item.center.y * side + drag.height)
    }

    private var size: CGFloat { side * NoteItem.baseSize * NoteItem.clampScale(item.scale * magnification) }

    private var rotation: Angle { item.rotation + turn }

    var body: some View {
        ZStack {
            accessiblePlaced
            if isSelected {
                TrashBadge(onRemove: onRemove)
                    .position(badgeCenter)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    private var placed: some View {
        content
            .frame(width: size, height: size)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color("Accent"), lineWidth: 2.5)
                        .padding(-8)
                        .environment(\.colorScheme, .light)
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .rotationEffect(rotation)
            .position(center)
            .onTapGesture(perform: onSelect)
            .gesture(edit)
    }

    private var accessiblePlaced: some View {
        placed
            .accessibilityElement()
            .accessibilityLabel(item.kind.label)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityAction(named: "Remove", onRemove)
            .accessibilityAction(named: "Make bigger") { item.scale = NoteItem.clampScale(item.scale * 1.25) }
            .accessibilityAction(named: "Make smaller") { item.scale = NoteItem.clampScale(item.scale / 1.25) }
            .accessibilityAction(named: "Rotate left") { item.rotation -= .degrees(15) }
            .accessibilityAction(named: "Rotate right") { item.rotation += .degrees(15) }
            .accessibilityAction(named: "Move up") { nudge(0, -0.05) }
            .accessibilityAction(named: "Move down") { nudge(0, 0.05) }
            .accessibilityAction(named: "Move left") { nudge(-0.05, 0) }
            .accessibilityAction(named: "Move right") { nudge(0.05, 0) }
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .sticker(let name):
            Stickers.image(name).resizable().scaledToFit()
        case .emoji(let emoji):
            Text(emoji).font(.system(size: size * 0.8))
        }
    }

    private var edit: some Gesture {
        move.simultaneously(with: resize).simultaneously(with: spin)
    }

    private var move: some Gesture {
        DragGesture()
            .updating($drag) { value, state, _ in state = value.translation }
            .onChanged { _ in onMove() }
            .onEnded { value in
                nudge(value.translation.width / side, value.translation.height / side)
            }
    }

    private var resize: some Gesture {
        MagnifyGesture()
            .updating($magnification) { value, state, _ in state = value.magnification }
            .onEnded { value in item.scale = NoteItem.clampScale(item.scale * value.magnification) }
    }

    private var spin: some Gesture {
        RotateGesture()
            .updating($turn) { value, state, _ in state = value.rotation }
            .onEnded { value in item.rotation += value.rotation }
    }

    private var badgeCenter: CGPoint {
        let half = size / 2 + 8
        let radius: CGFloat = 16
        let angle = rotation.radians
        let cosine = CGFloat(cos(angle)) * half
        let sine = CGFloat(sin(angle)) * half
        let corners: [CGPoint] = [(1.0, -1.0), (-1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)].map { (x: CGFloat, y: CGFloat) in
            CGPoint(x: center.x + x * cosine - y * sine, y: center.y + x * sine + y * cosine)
        }
        let inside = (radius...(side - radius))
        return corners.first { inside.contains($0.x) && inside.contains($0.y) }
            ?? CGPoint(x: min(max(corners[0].x, radius), side - radius), y: min(max(corners[0].y, radius), side - radius))
    }

    private func nudge(_ dx: CGFloat, _ dy: CGFloat) {
        item.center = NoteItem.clampCenter(CGPoint(x: item.center.x + dx, y: item.center.y + dy))
    }
}

struct TrashBadge: View {
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            Image(systemName: "trash")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color("Danger"))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color("Surface")))
                .overlay(Circle().strokeBorder(Color("Outline"), lineWidth: 2))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove sticker")
    }
}

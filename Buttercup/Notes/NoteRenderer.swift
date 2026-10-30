import PencilKit
import SwiftUI

enum NoteRenderer {
    @MainActor
    static func heic(_ draft: NoteDraft, side: CGFloat) -> Data? {
        let scale = 1000 / side
        var strokes = UIImage()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            strokes = draft.drawing.image(from: CGRect(x: 0, y: 0, width: side, height: side), scale: scale)
        }
        let note = ZStack {
            Color.white
            if let photo = draft.photo {
                Image(uiImage: photo).resizable().scaledToFill()
            }
            Image(uiImage: strokes).resizable()
            ForEach(draft.items) { item in
                NoteItemContent(kind: item.kind, side: side, scale: item.scale)
                    .rotationEffect(item.rotation)
                    .position(x: item.center.x * side, y: item.center.y * side)
            }
        }
        .frame(width: side, height: side)
        .clipped()
        .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: note)
        renderer.scale = scale
        return renderer.uiImage?.heicData()
    }
}

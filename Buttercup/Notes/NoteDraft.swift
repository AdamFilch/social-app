import Observation
import PencilKit
import UIKit

enum NoteMode {
    case draw, photo
}

@Observable
final class NoteDraft {
    var mode: NoteMode = .draw
    var photo: UIImage?
    var drawing = PKDrawing()
    var history: [PKDrawing] = []
    var items: [NoteItem] = []
    var selection: NoteItem.ID?

    var hasProgress: Bool {
        photo != nil || !drawing.strokes.isEmpty || !items.isEmpty
    }

    func undo() {
        guard let previous = history.popLast() else { return }
        drawing = previous
    }

    func add(_ kind: NoteItem.Kind, at center: CGPoint, select: Bool) {
        let item = NoteItem(kind: kind, center: NoteItem.clampCenter(center))
        items.append(item)
        if select { selection = item.id }
    }

    func remove(_ id: NoteItem.ID) {
        items.removeAll { $0.id == id }
        if selection == id { selection = nil }
    }

    func bringToFront(_ id: NoteItem.ID) {
        guard items.last?.id != id, let index = items.firstIndex(where: { $0.id == id }) else { return }
        items.append(items.remove(at: index))
    }

    func reset(to mode: NoteMode) {
        self.mode = mode
        photo = nil
        drawing = PKDrawing()
        history = []
        items = []
        selection = nil
    }
}

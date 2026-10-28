import Observation
import PencilKit
import UIKit

enum NoteMode {
    case draw, photo
}

struct NoteItem: Identifiable {
    let id = UUID()
}

@Observable
final class NoteDraft {
    var mode: NoteMode = .draw
    var photo: UIImage?
    var drawing = PKDrawing()
    var items: [NoteItem] = []
    var selection: NoteItem.ID?

    var hasProgress: Bool {
        photo != nil || !drawing.strokes.isEmpty || !items.isEmpty
    }

    func reset(to mode: NoteMode) {
        self.mode = mode
        photo = nil
        drawing = PKDrawing()
        items = []
        selection = nil
    }
}

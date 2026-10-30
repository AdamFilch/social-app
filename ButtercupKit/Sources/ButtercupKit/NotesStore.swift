import Foundation
import Observation
import SwiftData

@Model
public final class Note {
    @Attribute(.unique) public var id: UUID
    public var imagePath: String
    public var createdAt: Date

    init(id: UUID, imagePath: String) {
        self.id = id
        self.imagePath = imagePath
        createdAt = .now
    }
}

public enum NoteSendResult: Sendable {
    case online, offline
}

@Observable @MainActor
public final class NotesStore {
    public let outbox: Outbox

    public init(outbox: Outbox) {
        self.outbox = outbox
    }

    public func send(imageData: Data) throws -> NoteSendResult {
        let id = UUID()
        let note = Note(id: id, imagePath: "notes/\(id.uuidString.lowercased()).heic")
        let url = Outbox.directory.appending(path: note.imagePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try imageData.write(to: url)
        outbox.context.insert(note)
        let result: NoteSendResult = outbox.isOnline ? .online : .offline
        outbox.enqueue(OutboxAction(sendNote: .init(noteId: note.id, imagePath: note.imagePath)))
        return result
    }
}

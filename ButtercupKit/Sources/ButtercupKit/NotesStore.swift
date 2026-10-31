import Foundation
import Observation
import Supabase
import SwiftData
import UIKit

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

public struct NoteRecord: Decodable, Sendable, Identifiable {
    public let id: UUID
    public let senderId: UUID
    public let imagePath: String
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case imagePath = "image_path"
        case createdAt = "created_at"
    }
}

public enum NoteSendResult: Sendable {
    case online, offline
}

@Observable @MainActor
public final class NotesStore {
    public let outbox: Outbox
    private let images = NSCache<NSUUID, UIImage>()

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

    public func notes(in range: DateInterval) async throws -> [NoteRecord] {
        try await outbox.client.from("notes")
            .select("id, sender_id, image_path, created_at")
            .is("unsent_at", value: nil)
            .gte("created_at", value: range.start)
            .lt("created_at", value: range.end)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    public func image(for note: NoteRecord) async -> UIImage? {
        if let image = images.object(forKey: note.id as NSUUID) { return image }
        guard let data = try? await outbox.client.storage.from("notes").download(path: note.imagePath),
              let image = UIImage(data: data) else { return nil }
        images.setObject(image, forKey: note.id as NSUUID)
        return image
    }

    public func changes() -> AsyncStream<Void> {
        let client = outbox.client
        return AsyncStream { continuation in
            let task = Task {
                let channel = client.channel("notes")
                let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "notes")
                try? await channel.subscribeWithError()
                for await _ in changes { continuation.yield() }
                await client.removeChannel(channel)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

import Foundation
import Network
import Supabase
import SwiftData

@Model
public final class OutboxAction {
    public enum Kind: String, Codable {
        case sendNote, uploadSound
    }

    public struct SendNote: Codable {
        public let noteId: UUID
        public let imagePath: String
    }

    public struct UploadSound: Codable {
        public let soundId: UUID
        public let senderId: UUID
        public let filePath: String
        public let title: String
        public let durationMs: Int

        public init(soundId: UUID, senderId: UUID, filePath: String, title: String, durationMs: Int) {
            self.soundId = soundId
            self.senderId = senderId
            self.filePath = filePath
            self.title = title
            self.durationMs = durationMs
        }
    }

    @Attribute(.unique) public var id: UUID
    public var kind: Kind
    public var payload: Data
    public var createdAt: Date
    public var attempts: Int

    public init(sendNote: SendNote) {
        id = UUID()
        kind = .sendNote
        payload = (try? JSONEncoder().encode(sendNote)) ?? Data()
        createdAt = .now
        attempts = 0
    }

    public init(uploadSound: UploadSound) {
        id = UUID()
        kind = .uploadSound
        payload = (try? JSONEncoder().encode(uploadSound)) ?? Data()
        createdAt = .now
        attempts = 0
    }
}

private struct SoundRow: Encodable {
    let id: String
    let sender_id: String
    let title: String
    let audio_path: String
    let duration_ms: Int
    let trim_start_ms = 0
    let trim_end_ms: Int
}

@MainActor
public final class Outbox {
    public static let appGroup = "group.com.adamfilchoir.buttercup"
    public static let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)!

    public var isOnline: Bool { monitor.currentPath.status == .satisfied }
    public var onOnline: (() -> Void)?

    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let client: SupabaseClient
    private let monitor = NWPathMonitor()
    private var flushing = false
    private var again = false

    public init(client: SupabaseClient, container: ModelContainer) {
        self.client = client
        self.container = container
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in
                self?.onOnline?()
                await self?.flush()
            }
        }
        monitor.start(queue: .main)
    }

    public func enqueue(_ action: OutboxAction) {
        context.insert(action)
        try? context.save()
        Task { await flush() }
    }

    public func flush() async {
        guard !flushing else {
            again = true
            return
        }
        flushing = true
        repeat {
            again = false
            let actions = (try? context.fetch(FetchDescriptor<OutboxAction>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
            for action in actions {
                action.attempts += 1
                do {
                    try await perform(action)
                    context.delete(action)
                } catch {}
                try? context.save()
            }
        } while again
        flushing = false
    }

    private func perform(_ action: OutboxAction) async throws {
        switch action.kind {
        case .sendNote:
            let note = try JSONDecoder().decode(OutboxAction.SendNote.self, from: action.payload)
            let sender = try await client.auth.session.user.id
            let path = "\(sender.uuidString.lowercased())/\(note.noteId.uuidString.lowercased()).heic"
            let data = try Data(contentsOf: Self.directory.appending(path: note.imagePath))
            do {
                try await client.storage.from("notes").upload(path, data: data, options: FileOptions(contentType: "image/heic", upsert: false))
            } catch let error as StorageError where error.statusCode == "409" || error.error == "Duplicate" || error.message.localizedCaseInsensitiveContains("already exists") {}
            do {
                try await client.from("notes").insert(["id": note.noteId.uuidString, "sender_id": sender.uuidString, "image_path": path]).execute()
            } catch let error as PostgrestError where error.code == "23505" {}
        case .uploadSound:
            let sound = try JSONDecoder().decode(OutboxAction.UploadSound.self, from: action.payload)
            let id = sound.soundId.uuidString.lowercased()
            let path = "\(sound.senderId.uuidString.lowercased())/\(id).m4a"
            let data = try Data(contentsOf: Self.directory.appending(path: sound.filePath))
            do {
                try await client.storage.from("sounds").upload(path, data: data, options: FileOptions(contentType: "audio/mp4", upsert: false))
            } catch let error as StorageError where error.statusCode == "409" || error.error == "Duplicate" || error.message.localizedCaseInsensitiveContains("already exists") {}
            do {
                try await client.from("sounds").insert(SoundRow(id: id, sender_id: sound.senderId.uuidString.lowercased(), title: sound.title, audio_path: path, duration_ms: sound.durationMs, trim_end_ms: sound.durationMs)).execute()
            } catch let error as PostgrestError where error.code == "23505" {}
        }
    }
}

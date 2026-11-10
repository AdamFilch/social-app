import Foundation
import Network
import Supabase
import SwiftData

@Model
public final class OutboxAction {
    public enum Kind: String, Codable {
        case sendNote, uploadSound, updateSound, deleteSound, reorderSounds

        var isSound: Bool { self != .sendNote }
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

    public struct UpdateSound: Codable {
        public let soundId: UUID
        public let title: String
        public let emoji: String?
        public let trimStartMs: Int
        public let trimEndMs: Int
    }

    public struct DeleteSound: Codable {
        public let soundId: UUID
        public let audioPath: String
    }

    public struct ReorderSounds: Codable {
        public let ids: [UUID]

        public func apply(to current: [UUID]) -> [UUID] {
            let rank = Dictionary(ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
            return current.filter { rank[$0] == nil } + current.filter { rank[$0] != nil }.sorted { rank[$0]! < rank[$1]! }
        }
    }

    @Attribute(.unique) public var id: UUID
    public var kind: Kind
    public var payload: Data
    public var createdAt: Date
    public var attempts: Int

    public init(kind: Kind, payload: some Encodable) {
        id = UUID()
        self.kind = kind
        self.payload = (try? JSONEncoder().encode(payload)) ?? Data()
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
            var soundsBlocked = false
            for action in actions {
                if action.kind.isSound && soundsBlocked { continue }
                action.attempts += 1
                do {
                    try await perform(action)
                    context.delete(action)
                } catch {
                    if action.kind.isSound { soundsBlocked = true }
                }
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
        case .updateSound:
            let edit = try JSONDecoder().decode(OutboxAction.UpdateSound.self, from: action.payload)
            let values: [String: AnyJSON] = [
                "title": .string(edit.title),
                "emoji": edit.emoji.map(AnyJSON.string) ?? .null,
                "trim_start_ms": .integer(edit.trimStartMs),
                "trim_end_ms": .integer(edit.trimEndMs)
            ]
            do {
                try await client.from("sounds").update(values).eq("id", value: edit.soundId.uuidString.lowercased()).execute()
            } catch let error as PostgrestError where error.code == "23514" {}
        case .deleteSound:
            let sound = try JSONDecoder().decode(OutboxAction.DeleteSound.self, from: action.payload)
            try await client.from("sounds").delete().eq("id", value: sound.soundId.uuidString.lowercased()).execute()
            _ = try await client.storage.from("sounds").remove(paths: [sound.audioPath])
        case .reorderSounds:
            let reorder = try JSONDecoder().decode(OutboxAction.ReorderSounds.self, from: action.payload)
            struct Row: Decodable { let id: UUID }
            let current: [Row] = try await client.from("sounds").select("id").order("position").execute().value
            let ids = reorder.apply(to: current.map(\.id)).map { $0.uuidString.lowercased() }
            try await client.rpc("reorder_sounds", params: ["ordered_ids": ids]).execute()
        }
    }
}

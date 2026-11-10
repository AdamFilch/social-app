import Foundation
import Observation
import Supabase
import SwiftData

public struct SoundRecord: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let senderId: UUID
    public let title: String
    public let emoji: String?
    public let audioPath: String
    public let durationMs: Int
    public let trimStartMs: Int
    public let trimEndMs: Int
    public let position: Int

    public init(id: UUID, senderId: UUID, title: String, emoji: String? = nil, audioPath: String, durationMs: Int, trimStartMs: Int = 0, trimEndMs: Int? = nil, position: Int = 0) {
        self.id = id
        self.senderId = senderId
        self.title = title
        self.emoji = emoji
        self.audioPath = audioPath
        self.durationMs = durationMs
        self.trimStartMs = trimStartMs
        self.trimEndMs = trimEndMs ?? durationMs
        self.position = position
    }

    public func edited(title: String, emoji: String?, trimStartMs: Int, trimEndMs: Int) -> SoundRecord {
        SoundRecord(id: id, senderId: senderId, title: title, emoji: emoji, audioPath: audioPath, durationMs: durationMs, trimStartMs: trimStartMs, trimEndMs: trimEndMs, position: position)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, emoji, position
        case senderId = "sender_id"
        case audioPath = "audio_path"
        case durationMs = "duration_ms"
        case trimStartMs = "trim_start_ms"
        case trimEndMs = "trim_end_ms"
    }
}

@Observable @MainActor
public final class SoundsStore {
    public static let directory = Outbox.directory.appending(path: "Sounds")
    private static let listURL = directory.appending(path: "list.json")

    public enum SaveError: Error { case signedOut }

    public private(set) var cached: [SoundRecord]?
    public private(set) var pending: [SoundRecord] = []
    private var edits: [Edit] = []
    private let client: SupabaseClient
    private let outbox: Outbox

    private enum Edit {
        case update(OutboxAction.UpdateSound)
        case delete(UUID)
        case reorder(OutboxAction.ReorderSounds)
    }

    public var all: [SoundRecord]? {
        guard cached != nil || !pending.isEmpty else { return nil }
        let known = Set((cached ?? []).map(\.id))
        var list = pending.filter { !known.contains($0.id) } + (cached ?? [])
        for edit in edits {
            switch edit {
            case .update(let change):
                guard let i = list.firstIndex(where: { $0.id == change.soundId }) else { continue }
                list[i] = list[i].edited(title: change.title, emoji: change.emoji, trimStartMs: change.trimStartMs, trimEndMs: change.trimEndMs)
            case .delete(let id):
                list.removeAll { $0.id == id }
            case .reorder(let order):
                let byID = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                list = order.apply(to: list.map(\.id)).compactMap { byID[$0] }
            }
        }
        return list
    }

    public init(client: SupabaseClient, outbox: Outbox) {
        self.client = client
        self.outbox = outbox
        cached = (try? Data(contentsOf: Self.listURL)).flatMap { try? JSONDecoder().decode([SoundRecord].self, from: $0) }
        reloadQueue()
    }

    private func reloadQueue() {
        let actions = ((try? outbox.context.fetch(FetchDescriptor<OutboxAction>(sortBy: [SortDescriptor(\.createdAt)]))) ?? [])
            .filter(\.kind.isSound)
        let decoder = JSONDecoder()
        pending = actions.reversed()
            .filter { $0.kind == .uploadSound }
            .compactMap { try? decoder.decode(OutboxAction.UploadSound.self, from: $0.payload) }
            .map(Self.record)
        edits = actions.compactMap { action in
            switch action.kind {
            case .updateSound: (try? decoder.decode(OutboxAction.UpdateSound.self, from: action.payload)).map(Edit.update)
            case .deleteSound: (try? decoder.decode(OutboxAction.DeleteSound.self, from: action.payload)).map { .delete($0.soundId) }
            case .reorderSounds: (try? decoder.decode(OutboxAction.ReorderSounds.self, from: action.payload)).map(Edit.reorder)
            default: nil
            }
        }
    }

    private func enqueue(_ kind: OutboxAction.Kind, _ payload: some Encodable) {
        outbox.enqueue(OutboxAction(kind: kind, payload: payload))
        reloadQueue()
    }

    private static func record(_ sound: OutboxAction.UploadSound) -> SoundRecord {
        SoundRecord(
            id: sound.soundId,
            senderId: sound.senderId,
            title: sound.title,
            audioPath: "\(sound.senderId.uuidString.lowercased())/\(sound.soundId.uuidString.lowercased()).m4a",
            durationMs: sound.durationMs
        )
    }

    public func save(fileURL: URL, title: String, durationMs: Int) throws {
        guard let sender = client.auth.currentUser?.id else { throw SaveError.signedOut }
        let id = UUID()
        let upload = OutboxAction.UploadSound(
            soundId: id,
            senderId: sender,
            filePath: "Sounds/\(id.uuidString.lowercased()).m4a",
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            durationMs: min(max(durationMs, 1), 10000)
        )
        let record = Self.record(upload)
        try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: fileURL, to: localURL(for: record))
        enqueue(.uploadSound, upload)
    }

    public func update(_ sound: SoundRecord, title: String, emoji: String?, trimStartMs: Int, trimEndMs: Int) {
        enqueue(.updateSound, OutboxAction.UpdateSound(
            soundId: sound.id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            emoji: emoji,
            trimStartMs: trimStartMs,
            trimEndMs: trimEndMs
        ))
    }

    public func delete(_ sound: SoundRecord) {
        enqueue(.deleteSound, OutboxAction.DeleteSound(soundId: sound.id, audioPath: sound.audioPath))
    }

    public func reorder(_ ids: [UUID]) {
        enqueue(.reorderSounds, OutboxAction.ReorderSounds(ids: ids))
    }

    public func sounds() async throws -> [SoundRecord] {
        let rows: [SoundRecord] = try await client.from("sounds")
            .select("id, sender_id, title, emoji, audio_path, duration_ms, trim_start_ms, trim_end_ms, position")
            .order("position")
            .execute()
            .value
        cached = rows
        try? FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(rows).write(to: Self.listURL, options: .atomic)
        reloadQueue()
        let keep = Set((rows + pending).map { localURL(for: $0).lastPathComponent } + [Self.listURL.lastPathComponent])
        for url in (try? FileManager.default.contentsOfDirectory(at: Self.directory, includingPropertiesForKeys: nil)) ?? [] where !keep.contains(url.lastPathComponent) {
            try? FileManager.default.removeItem(at: url)
        }
        Task {
            for row in rows { _ = try? await file(for: row) }
        }
        return all ?? rows
    }

    public func localURL(for sound: SoundRecord) -> URL {
        Self.directory.appending(path: "\(sound.id.uuidString.lowercased()).m4a")
    }

    public func file(for sound: SoundRecord) async throws -> URL {
        let url = localURL(for: sound)
        if FileManager.default.fileExists(atPath: url.path()) { return url }
        let data = try await client.storage.from("sounds").download(path: sound.audioPath)
        try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return url
    }

    public func changes() -> AsyncStream<Void> {
        let client = client
        return AsyncStream { continuation in
            let task = Task {
                let channel = client.channel("sounds")
                let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "sounds")
                while (try? await channel.subscribeWithError()) == nil, !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5))
                }
                continuation.yield()
                for await _ in changes { continuation.yield() }
                await client.removeChannel(channel)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

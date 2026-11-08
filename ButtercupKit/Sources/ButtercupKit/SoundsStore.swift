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
    private let client: SupabaseClient
    private let outbox: Outbox

    public var all: [SoundRecord]? {
        guard cached != nil || !pending.isEmpty else { return nil }
        let known = Set((cached ?? []).map(\.id))
        return pending.filter { !known.contains($0.id) } + (cached ?? [])
    }

    public init(client: SupabaseClient, outbox: Outbox) {
        self.client = client
        self.outbox = outbox
        pending = ((try? outbox.context.fetch(FetchDescriptor<OutboxAction>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? [])
            .filter { $0.kind == .uploadSound }
            .compactMap { try? JSONDecoder().decode(OutboxAction.UploadSound.self, from: $0.payload) }
            .map(Self.record)
        cached = (try? Data(contentsOf: Self.listURL)).flatMap { try? JSONDecoder().decode([SoundRecord].self, from: $0) }
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
        pending.insert(record, at: 0)
        outbox.enqueue(OutboxAction(uploadSound: upload))
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
        let arrived = Set(rows.map(\.id))
        pending.removeAll { arrived.contains($0.id) }
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

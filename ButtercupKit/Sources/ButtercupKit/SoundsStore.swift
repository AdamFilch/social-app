import Foundation
import Observation
import Supabase

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

    public private(set) var cached: [SoundRecord]?
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
        cached = (try? Data(contentsOf: Self.listURL)).flatMap { try? JSONDecoder().decode([SoundRecord].self, from: $0) }
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
        let keep = Set(rows.map { localURL(for: $0).lastPathComponent } + [Self.listURL.lastPathComponent])
        for url in (try? FileManager.default.contentsOfDirectory(at: Self.directory, includingPropertiesForKeys: nil)) ?? [] where !keep.contains(url.lastPathComponent) {
            try? FileManager.default.removeItem(at: url)
        }
        Task {
            for row in rows { _ = try? await file(for: row) }
        }
        return rows
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

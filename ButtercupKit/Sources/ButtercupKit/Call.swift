import Foundation

public struct Call: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let roomName: String
    public let callerId: UUID
    public let calleeId: UUID
    public let kind: String
    public let status: String
    public let createdAt: Date
    public let answeredAt: Date?
    public let endedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, kind, status
        case roomName = "room_name"
        case callerId = "caller_id"
        case calleeId = "callee_id"
        case createdAt = "created_at"
        case answeredAt = "answered_at"
        case endedAt = "ended_at"
    }

    public var isVideo: Bool { kind == "video" }
    public var isActive: Bool { status == "ringing" || status == "answered" }

    public var duration: TimeInterval? {
        guard let answeredAt, let endedAt else { return nil }
        return endedAt.timeIntervalSince(answeredAt)
    }
}

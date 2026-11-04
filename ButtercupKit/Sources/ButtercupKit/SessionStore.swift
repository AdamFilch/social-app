import Foundation
import Observation
import Supabase

public struct Profile: Codable, Sendable, Identifiable {
    public let id: UUID
    public let displayName: String
    public let timeZone: String
    public let avatarTint: String?
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case timeZone = "time_zone"
        case avatarTint = "avatar_tint"
        case createdAt = "created_at"
    }
}

@Observable @MainActor
public final class SessionStore {
    public enum State: Equatable {
        case loading, offline, signedOut, needsName, unpaired, ready
    }

    public static let tints = ["NotePaperBlue", "NotePaperPink", "NotePaperGreen", "NotePaperLilac", "NotePaperYellow"]

    public let client: SupabaseClient
    public private(set) var state: State = .loading
    public private(set) var me: Profile?
    public private(set) var partner: Profile?
    public private(set) var pairedAt: Date?
    public var inviteError: String?
    private var pendingInviteCode: String?

    public init() {
        let info = Bundle.main.infoDictionary ?? [:]
        client = SupabaseClient(
            supabaseURL: URL(string: info["SUPABASE_URL"] as? String ?? "")!,
            supabaseKey: info["SUPABASE_ANON_KEY"] as? String ?? ""
        )
    }

    public func refresh() async {
        let user: User
        do {
            user = try await client.auth.session.user
        } catch {
            if error is URLError, client.auth.currentSession != nil { return restore() }
            me = nil
            partner = nil
            pairedAt = nil
            Self.defaults?.removeObject(forKey: Self.savedKey)
            state = .signedOut
            return
        }
        guard let profiles: [Profile] = try? await client.from("profiles").select().execute().value else { return restore() }
        me = profiles.first { $0.id == user.id }
        partner = profiles.first { $0.id != user.id }
        let pairs: [[String: Date]]? = try? await client.from("pairs").select("created_at").execute().value
        pairedAt = pairs?.first?["created_at"]
        Self.defaults?.set(try? JSONEncoder().encode(Saved(me: me, partner: partner, pairedAt: pairedAt)), forKey: Self.savedKey)
        if me?.displayName.isEmpty ?? true {
            state = .needsName
        } else if partner == nil {
            state = .unpaired
            if let code = pendingInviteCode {
                pendingInviteCode = nil
                await acceptInvite(code)
            }
        } else {
            state = .ready
            await pickTintIfNeeded()
        }
    }

    public func sendCode(to email: String) async throws {
        try await client.auth.signInWithOTP(email: email)
    }

    public func verify(email: String, code: String) async throws {
        try await client.auth.verifyOTP(email: email, token: code, type: .email)
        await refresh()
    }

    public func saveName(_ name: String) async throws {
        guard let me else { return }
        try await client.from("profiles")
            .update(["display_name": name, "time_zone": TimeZone.current.identifier])
            .eq("id", value: me.id)
            .execute()
        await refresh()
    }

    public func createInvite() async throws -> String {
        let row: [String: String] = try await client.from("pair_invites")
            .insert([String: String](), returning: .representation)
            .select("code")
            .single()
            .execute()
            .value
        return row["code"] ?? ""
    }

    public func openInvite(_ url: URL) async {
        guard state != .ready, url.scheme == "buttercup", url.host() == "invite", !url.lastPathComponent.isEmpty else { return }
        pendingInviteCode = url.lastPathComponent
        if state == .unpaired { await refresh() }
    }

    public func acceptInvite(_ code: String) async {
        inviteError = nil
        do {
            try await client.rpc("accept_invite", params: ["p_code": code]).execute()
            await refresh()
        } catch {
            let message = (error as? PostgrestError)?.message ?? ""
            inviteError = switch message {
            case "invite_not_found": "That code isn't right."
            case "invite_expired": "That invite has expired. Ask for a new one."
            case "invite_used": "That invite was already used."
            case "cannot_pair_self": "That's your own invite."
            case "already_paired": "You're already paired."
            default: "Couldn't pair. Try again."
            }
        }
    }

    public func signOut() async {
        try? await client.auth.signOut()
        await refresh()
    }

    private struct Saved: Codable {
        let me: Profile?
        let partner: Profile?
        let pairedAt: Date?
    }

    private static let savedKey = "session"
    private static let defaults = UserDefaults(suiteName: Outbox.appGroup)

    private func restore() {
        guard state == .loading || state == .offline else { return }
        guard let data = Self.defaults?.data(forKey: Self.savedKey),
              let saved = try? JSONDecoder().decode(Saved.self, from: data) else {
            state = .offline
            return
        }
        me = saved.me
        partner = saved.partner
        pairedAt = saved.pairedAt
        state = me?.displayName.isEmpty ?? true ? .needsName : partner == nil ? .unpaired : .ready
    }

    private func pickTintIfNeeded() async {
        guard let me, let partner else { return }
        let collides = me.avatarTint == partner.avatarTint && me.createdAt > partner.createdAt
        guard me.avatarTint == nil || collides,
              let tint = Self.tints.first(where: { $0 != partner.avatarTint }) else { return }
        _ = try? await client.from("profiles").update(["avatar_tint": tint]).eq("id", value: me.id).execute()
    }
}

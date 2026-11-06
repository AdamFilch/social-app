import Foundation
@_exported import LiveKit
import Observation
import Supabase

@Observable @MainActor
public final class CallStore: NSObject {
    public enum Phase: Equatable, Sendable {
        case idle, outgoing, incoming, connecting, active, reconnecting
    }

    public enum Failure: Equatable, Sendable {
        case unreachable, busy
    }

    public private(set) var phase: Phase = .idle
    public private(set) var call: Call?
    public private(set) var history: [Call]?
    public private(set) var connectedAt: Date?
    public private(set) var remoteVideo: VideoTrack?
    public private(set) var localVideo: VideoTrack?
    public private(set) var micOn = true
    public private(set) var cameraOn = false
    public private(set) var front = true
    public var failure: Failure?
    public var showsCallScreen: Bool {
        (phase == .outgoing && call != nil) || [.connecting, .active, .reconnecting].contains(phase)
    }
    public var videoSource: ((BufferCapturer) -> Void)?
    public var videoStop: (() -> Void)?

    private let session: SessionStore
    private var room: Room?
    private var timeout: Task<Void, Never>?
    private var listening = false
    private var reconnecting = false

    public init(session: SessionStore) {
        self.session = session
    }

    public func listen() async {
        guard !listening else { return }
        listening = true
        let channel = session.client.channel("calls")
        let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "calls")
        try? await channel.subscribeWithError()
        for await change in changes {
            let row: Call? = switch change {
            case .insert(let action): try? action.decodeRecord(as: Call.self, decoder: AnyJSON.decoder)
            case .update(let action): try? action.decodeRecord(as: Call.self, decoder: AnyJSON.decoder)
            default: nil
            }
            if let row { await apply(row) }
        }
        await session.client.removeChannel(channel)
        listening = false
    }

    public func resync() async {
        guard let me = session.me?.id else { return }
        let query = session.client.from("calls").select()
        let rows: [Call]? = if let call {
            try? await query.eq("id", value: call.id).execute().value
        } else {
            try? await query.eq("callee_id", value: me).eq("status", value: "ringing").execute().value
        }
        for row in rows ?? [] { await apply(row) }
    }

    public func loadHistory() async {
        history = try? await session.client.from("calls").select()
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
    }

    public func startCall(video: Bool) async {
        guard phase == .idle else { return }
        phase = .outgoing
        do {
            let response = try await invoke("start-call", ["kind": video ? "video" : "audio"])
            guard phase == .outgoing, call == nil else { return }
            call = response.call
            if response.incoming == true {
                phase = .incoming
                return
            }
            timeout = Task {
                try? await Task.sleep(for: .seconds(45))
                guard !Task.isCancelled, phase == .outgoing else { return }
                timeout = nil
                await end("missed")
            }
            try await join(response, camera: video)
        } catch {
            await fail(error)
        }
    }

    public func answer() async {
        guard phase == .incoming, let call else { return }
        phase = .connecting
        do {
            let response = try await invoke("answer-call", ["call_id": call.id.uuidString])
            self.call = response.call
            try await join(response, camera: call.isVideo)
        } catch where errorCode(error) == "call_not_ringing" {
            leave()
        } catch {
            await fail(error)
        }
    }

    public func end(_ reason: String? = nil) async {
        guard let call else { return leave() }
        let fallback = switch phase {
        case .outgoing: "cancelled"
        case .incoming: "declined"
        default: "ended"
        }
        let reason = reason ?? fallback
        leave()
        do {
            _ = try await invoke("end-call", ["call_id": call.id.uuidString, "reason": reason])
        } catch {
            failure = .unreachable
        }
        await loadHistory()
    }

    public func toggleMic() async {
        guard let room else { return }
        let on = !micOn
        do {
            try await room.localParticipant.setMicrophone(enabled: on)
            micOn = on
        } catch {
            micOn = false
        }
    }

    public func toggleCamera() async {
        await setCamera(!cameraOn)
    }

    public func flipCamera() async {
        #if !targetEnvironment(simulator)
        front.toggle()
        if cameraOn { await setCamera(true) }
        #endif
    }

    private func setCamera(_ on: Bool) async {
        guard let room else { return }
        videoStop?()
        for publication in room.localParticipant.videoTracks {
            if let publication = publication as? LocalTrackPublication {
                try? await room.localParticipant.unpublish(publication: publication)
            }
        }
        do {
            if on, front, let videoSource {
                let track = await LocalVideoTrack.createBufferTrack(name: "camera", source: .camera)
                if let capturer = track.capturer as? BufferCapturer { videoSource(capturer) }
                try await room.localParticipant.publish(videoTrack: track)
            } else if on {
                try await room.localParticipant.setCamera(enabled: true, captureOptions: CameraCaptureOptions(position: front ? .front : .back))
            }
            cameraOn = on
        } catch {
            cameraOn = false
        }
        sync()
    }

    private func apply(_ row: Call) async {
        if row.status == "ringing", row.calleeId == session.me?.id,
           phase == .idle || (phase == .outgoing && call == nil) {
            call = row
            phase = .incoming
            return
        }
        if row.id == call?.id {
            call = row
            if !row.isActive {
                leave()
            } else if row.status == "answered", phase == .outgoing {
                phase = .connecting
                sync()
            }
        }
        if !row.isActive { await loadHistory() }
    }

    private func join(_ response: Response, camera: Bool) async throws {
        guard let token = response.token, let url = response.livekitUrl else { throw URLError(.badServerResponse) }
        let room = Room(delegate: self)
        self.room = room
        try await room.connect(url: url, token: token)
        guard self.room === room else { return await room.disconnect() }
        do {
            try await room.localParticipant.setMicrophone(enabled: true)
        } catch {
            micOn = false
        }
        if camera { await setCamera(true) }
        sync()
    }

    private func sync() {
        guard let room else { return }
        let partner = room.remoteParticipants.values.first
        remoteVideo = partner?.videoTracks.first { $0.isSubscribed && !$0.isMuted }?.track as? VideoTrack
        localVideo = room.localParticipant.videoTracks.first { !$0.isMuted }?.track as? VideoTrack
        guard [.connecting, .active, .reconnecting].contains(phase) else { return }
        if partner != nil, room.connectionState == .connected, !reconnecting {
            guard phase != .active else { return }
            timeout?.cancel()
            phase = .active
            connectedAt = connectedAt ?? .now
        } else if phase == .active {
            phase = .reconnecting
            timeout = Task {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, phase == .reconnecting else { return }
                timeout = nil
                await end("ended")
            }
        }
    }

    private func leave() {
        timeout?.cancel()
        timeout = nil
        let room = room
        self.room = nil
        call = nil
        phase = .idle
        connectedAt = nil
        remoteVideo = nil
        localVideo = nil
        micOn = true
        cameraOn = false
        front = true
        reconnecting = false
        videoStop?()
        if let room { Task { await room.disconnect() } }
    }

    private func fail(_ error: Error) async {
        failure = errorCode(error) == "busy" ? .busy : .unreachable
        await end()
    }

    private struct Response: Decodable {
        let call: Call
        let token: String?
        let livekitUrl: String?
        let incoming: Bool?

        enum CodingKeys: String, CodingKey {
            case call, token, incoming
            case livekitUrl = "livekit_url"
        }
    }

    private struct ErrorBody: Decodable {
        let error: String
    }

    private func invoke(_ name: String, _ body: [String: String]) async throws -> Response {
        try await session.client.functions.invoke(name, options: .init(body: body), decoder: AnyJSON.decoder)
    }

    private func errorCode(_ error: Error) -> String? {
        guard case let FunctionsError.httpError(_, data) = error else { return nil }
        return try? JSONDecoder().decode(ErrorBody.self, from: data).error
    }
}

extension CallStore: RoomDelegate {
    private nonisolated func changed() {
        Task { @MainActor in sync() }
    }

    private nonisolated func reconnect(_ on: Bool) {
        Task { @MainActor in
            reconnecting = on
            sync()
        }
    }

    public nonisolated func room(_: Room, didStartReconnectWithMode _: ReconnectMode) { reconnect(true) }
    public nonisolated func room(_: Room, didCompleteReconnectWithMode _: ReconnectMode) { reconnect(false) }
    public nonisolated func room(_: Room, didUpdateConnectionState _: ConnectionState, from _: ConnectionState) { changed() }
    public nonisolated func room(_: Room, participantDidConnect _: RemoteParticipant) { changed() }
    public nonisolated func room(_: Room, participantDidDisconnect _: RemoteParticipant) { changed() }
    public nonisolated func room(_: Room, participant _: RemoteParticipant, didSubscribeTrack _: RemoteTrackPublication) { changed() }
    public nonisolated func room(_: Room, participant _: RemoteParticipant, didUnsubscribeTrack _: RemoteTrackPublication) { changed() }
    public nonisolated func room(_: Room, participant _: Participant, trackPublication _: TrackPublication, didUpdateIsMuted _: Bool) { changed() }
    public nonisolated func room(_: Room, participant _: LocalParticipant, didPublishTrack _: LocalTrackPublication) { changed() }
}

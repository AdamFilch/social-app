import ButtercupKit
import SwiftUI

struct InCallView: View {
    @Environment(SessionStore.self) private var session
    @Environment(CallStore.self) private var calls
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tile = Tile.small

    enum Tile {
        case small, mid, swapped
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if tile == .swapped { me } else { partner }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { if tile == .mid { tile = .small } }

            smallTile
                .id(reduceMotion ? tile : .small)
                .transition(.opacity)
                .padding(16)

            VStack(spacing: 8) {
                status
                Spacer()
                bar
            }
            .frame(maxWidth: .infinity)
        }
        .background(.black)
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .smooth, value: tile)
    }

    private var me: some View {
        Feed(track: calls.localVideo, profile: session.me, mirror: calls.front)
    }

    private var partner: some View {
        Feed(track: calls.remoteVideo, profile: session.partner)
    }

    private var smallTile: some View {
        let size = tile == .mid ? CGSize(width: 180, height: 260) : CGSize(width: 100, height: 150)
        return Group {
            if tile == .swapped { partner } else { me }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(alignment: .bottom) {
            if tile == .mid {
                HStack {
                    Button("Flip", systemImage: "arrow.triangle.2.circlepath.camera") {
                        Task { await calls.flipCamera() }
                    }
                    Spacer()
                    Button("Expand", systemImage: "arrow.up.left.and.arrow.down.right") { tile = .swapped }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .tint(.white)
                .padding(8)
            }
        }
        .onTapGesture { tile = tile == .small ? .mid : .small }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(tile == .swapped ? "Partner tile" : "Your tile")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private var status: some View {
        switch calls.phase {
        case .reconnecting:
            Text("Reconnecting…").font(.headline).padding(8).background(.ultraThinMaterial, in: .capsule)
        case .connecting:
            Text("Connecting…").font(.headline).padding(8).background(.ultraThinMaterial, in: .capsule)
        default:
            if let start = calls.connectedAt {
                Text(start, style: .timer)
                    .font(.headline.monospacedDigit())
                    .padding(8)
                    .background(.ultraThinMaterial, in: .capsule)
            }
        }
    }

    private var bar: some View {
        HStack(spacing: 20) {
            Button(calls.micOn ? "Mute" : "Unmute", systemImage: calls.micOn ? "mic.fill" : "mic.slash.fill") {
                Task { await calls.toggleMic() }
            }
            Button(calls.cameraOn ? "Camera off" : "Camera on", systemImage: calls.cameraOn ? "video.fill" : "video.slash.fill") {
                Task { await calls.toggleCamera() }
            }
            SwiftUIAudioRoutePickerButton()
                .frame(width: 44, height: 44)
                .accessibilityLabel("Audio route")
            Button("Hang up", systemImage: "phone.down.fill") {
                Task { await calls.end() }
            }
            .tint(Color("Danger"))
        }
        .labelStyle(.iconOnly)
        .font(.title2)
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .tint(.white.opacity(0.25))
        .padding(12)
        .background(.ultraThinMaterial, in: .capsule)
        .padding(.bottom, 8)
    }
}

struct Feed: View {
    let track: VideoTrack?
    let profile: Profile?
    var mirror = false

    var body: some View {
        if let track {
            SwiftUIVideoView(track, layoutMode: .fill, mirrorMode: mirror ? .mirror : .off)
        } else {
            Color(white: 0.15).overlay { Avatar(profile: profile, size: 88) }
        }
    }
}

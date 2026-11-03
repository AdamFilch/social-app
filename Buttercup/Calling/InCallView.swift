import ButtercupKit
import SwiftUI

struct InCallView: View {
    @Environment(SessionStore.self) private var session
    @Environment(CallStore.self) private var calls
    @Environment(StickerLayer.self) private var stickers
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tile = Tile.small
    @State private var tray = false
    @State private var detent = PresentationDetent.medium

    enum Tile {
        case small, mid, swapped
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if tile == .swapped { me } else { partner }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if editing { StickerGestures(mirror: calls.front) }
            }
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
                if editing, let id = stickers.selected {
                    Button("Remove sticker", systemImage: "trash") { stickers.remove(id) }
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.circle)
                        .tint(Color("Danger"))
                        .transition(.opacity)
                }
                bar
            }
            .frame(maxWidth: .infinity)
        }
        .background(.black)
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .smooth, value: tile)
        .animation(.easeOut(duration: 0.15), value: stickers.selected)
        .sheet(isPresented: $tray) {
            StickerTray(detent: $detent)
                .presentationDetents([StickerTray.small, .medium], selection: $detent)
                .presentationBackgroundInteraction(.enabled)
                .presentationDragIndicator(.visible)
        }
        .onChange(of: editing) { _, on in
            if !on {
                tray = false
                stickers.selected = nil
            }
        }
        .onChange(of: stickers.selected) { _, id in
            if id != nil { tray = false }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: stickers.drops)
    }

    private var editing: Bool {
        tile == .swapped && calls.cameraOn && calls.front
    }

    private var me: some View {
        Feed(track: calls.localVideo, profile: session.me, mirror: calls.front, preview: calls.front && calls.videoSource != nil ? stickers.compositor.preview : nil)
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
                    if calls.cameraOn, calls.front {
                        Button("Add sticker", systemImage: "face.smiling") {
                            detent = .medium
                            tile = .swapped
                            tray = true
                        }
                        Spacer()
                    }
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
    var preview: CALayer?

    var body: some View {
        if track != nil, let preview {
            LayerView(layer: preview)
        } else if let track {
            SwiftUIVideoView(track, layoutMode: .fill, mirrorMode: mirror ? .mirror : .off)
        } else {
            Color(white: 0.15).overlay { Avatar(profile: profile, size: 88) }
        }
    }
}

private struct LayerView: UIViewRepresentable {
    let layer: CALayer

    func makeUIView(context _: Context) -> Host {
        Host(hosted: layer)
    }

    func updateUIView(_: Host, context _: Context) {}

    final class Host: UIView {
        let hosted: CALayer

        init(hosted: CALayer) {
            self.hosted = hosted
            super.init(frame: .zero)
        }

        required init?(coder _: NSCoder) { nil }

        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.addSublayer(hosted)
            hosted.frame = bounds
            CATransaction.commit()
        }
    }
}

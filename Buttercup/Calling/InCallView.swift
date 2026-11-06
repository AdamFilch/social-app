import AVKit
import ButtercupKit
import Combine
import SwiftUI

struct InCallView: View {
    @Environment(SessionStore.self) private var session
    @Environment(CallStore.self) private var calls
    @Environment(StickerLayer.self) private var stickers
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var meBig = false
    @State private var medium = false
    @State private var corner = Corner.topTrailing
    @State private var drag = CGSize.zero
    @State private var panel = false
    @State private var hovering = false
    @State private var scheme = ColorScheme.light
    @State private var screenHeight: CGFloat = 896
    @State private var bottomInset: CGFloat = 34

    enum Corner: CaseIterable {
        case topLeading, topTrailing, bottomLeading, bottomTrailing

        var top: Bool { self == .topLeading || self == .topTrailing }
        var leading: Bool { self == .topLeading || self == .bottomLeading }

        var name: String {
            switch self {
            case .topLeading: "top left"
            case .topTrailing: "top right"
            case .bottomLeading: "bottom left"
            case .bottomTrailing: "bottom right"
            }
        }
    }

    private var partnerName: String { session.partner?.displayName ?? "" }
    private var faceAllowed: Bool { calls.cameraOn && calls.front }
    private var editing: Bool { meBig && faceAllowed }
    private var panelHeight: CGFloat { screenHeight / 2 - bottomInset }
    private var tileTravel: Animation { reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.3) }

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                chrome(geo)
            }
            .ignoresSafeArea(.keyboard)
            .onGeometryChange(for: [CGFloat].self) { [$0.size.height + $0.safeAreaInsets.top + $0.safeAreaInsets.bottom, $0.safeAreaInsets.bottom] } action: {
                screenHeight = $0[0]
                bottomInset = $0[1]
            }

            if panel {
                EffectsPanel(height: panelHeight, faceAllowed: faceAllowed, onClose: closePanel, onAdd: add)
                    .offset(y: hovering ? screenHeight / 2 : 0)
                    .opacity(hovering ? 0 : 1)
                    .environment(\.colorScheme, scheme)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(.black)
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .animation(.easeOut(duration: 0.15), value: stickers.selected)
        .animation(.easeOut(duration: 0.2), value: calls.cameraOn)
        .onChange(of: editing) { _, on in
            if !on { stickers.selected = nil }
        }
        .onChange(of: stickers.selected) { _, id in
            if id != nil, panel { closePanel() }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: stickers.drops)
    }

    private func chrome(_ geo: GeometryProxy) -> some View {
        let size = geo.size
        let barTop = size.height - 68
        return ZStack {
            Group {
                if meBig { me(big: true) } else { partner(big: true) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if editing {
                    StickerGestures(mirror: calls.front, panelTop: screenHeight / 2, hovering: $hovering) {
                        closePanel()
                    }
                }
            }
            .clipped()
            .ignoresSafeArea()
            .accessibilityElement(children: .contain)
            .accessibilityLabel(bigLabel)

            NamePill(name: partnerName, start: calls.connectedAt, status: status)
                .frame(maxWidth: 220)
                .position(x: size.width / 2, y: 26)

            if medium {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { shrink() }
                    .accessibilityAction(.escape, shrink)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }

            if !panel || hovering {
                bar
                    .frame(width: size.width - 32)
                    .position(x: size.width / 2, y: size.height - 40)
                    .transition(.opacity)
                if editing, stickers.selected != nil {
                    CallControlButton(symbol: "trash", label: "Remove sticker", tint: Color("Danger")) {
                        if let id = stickers.selected { stickers.remove(id) }
                    }
                    .position(x: size.width / 2, y: barTop - 16 - 28)
                    .transition(.opacity)
                }
            }

            tile(size: size, barTop: barTop)
        }
        .animation(.easeOut(duration: panel ? 0.15 : 0.2), value: panel)
    }

    private var status: String? {
        switch calls.phase {
        case .reconnecting: "Reconnecting…"
        case .connecting: "Connecting…"
        default: nil
        }
    }

    private var bigLabel: String {
        if meBig { calls.cameraOn ? "Your video" : "You, camera off" } else { calls.remoteVideo != nil ? "\(partnerName)'s video" : "\(partnerName), camera off" }
    }

    private func me(big: Bool, avatar: CGFloat = 56) -> some View {
        Feed(
            track: calls.localVideo,
            profile: session.me,
            mirror: calls.front,
            preview: calls.front && calls.videoSource != nil ? stickers.compositor.preview : nil,
            avatar: big ? 128 : avatar,
            big: big
        )
    }

    private func partner(big: Bool, avatar: CGFloat = 56) -> some View {
        Feed(track: calls.remoteVideo, profile: session.partner, avatar: big ? 128 : avatar, big: big)
    }

    private func center(_ corner: Corner, size: CGSize, barTop: CGFloat) -> CGPoint {
        CGPoint(
            x: corner.leading ? 16 + 50 : size.width - 16 - 50,
            y: corner.top ? 8 + 75 : barTop - 16 - 75
        )
    }

    private func tile(size: CGSize, barTop: CGFloat) -> some View {
        let shown = panel && meBig ? (corner.leading ? Corner.topLeading : .topTrailing) : corner
        let mediumWidth = (size.width) * 0.7
        let tileSize = medium ? CGSize(width: mediumWidth, height: mediumWidth * 1.5) : CGSize(width: 100, height: 150)
        let origin = medium ? CGPoint(x: size.width / 2, y: barTop / 2) : center(shown, size: size, barTop: barTop)
        return Group {
            if meBig { partner(big: false, avatar: medium ? 96 : 56) } else { me(big: false, avatar: medium ? 96 : 56) }
        }
        .frame(width: tileSize.width, height: tileSize.height)
        .clipShape(.rect(cornerRadius: medium ? 28 : 20, style: .continuous))
        .contentShape(.rect(cornerRadius: medium ? 28 : 20, style: .continuous))
        .overlay { if medium { tileButtons.transition(.opacity) } }
        .shadow(color: .black.opacity(medium ? 0.45 : 0.35), radius: medium ? 20 : 10, y: medium ? 12 : 6)
        .onTapGesture {
            guard !medium, !panel else { return }
            withAnimation(.easeOut(duration: 0.25)) { medium = true }
        }
        .gesture(DragGesture(minimumDistance: 10)
            .onChanged { drag = $0.translation }
            .onEnded { value in
                let start = center(corner, size: size, barTop: barTop)
                let projected = CGPoint(
                    x: start.x + value.translation.width + value.velocity.width * 0.15,
                    y: start.y + value.translation.height + value.velocity.height * 0.15
                )
                let target = Corner.allCases.min { a, b in
                    distance(center(a, size: size, barTop: barTop), projected) < distance(center(b, size: size, barTop: barTop), projected)
                } ?? corner
                withAnimation(tileTravel) {
                    corner = target
                    drag = .zero
                }
            }, including: medium || panel ? .subviews : .all
        )
        .offset(medium ? .zero : drag)
        .id(reduceMotion ? AnyHashable(shown) : AnyHashable(0))
        .transition(.opacity)
        .position(origin)
        .animation(tileTravel, value: shown)
        .accessibilityElement(children: medium ? .contain : .ignore)
        .accessibilityLabel(tileLabel)
        .accessibilityHint(medium ? "" : (meBig ? "Double-tap to show options" : "Double-tap for camera options"))
        .accessibilityAddTraits(medium ? [] : .isButton)
        .accessibilityAction { if !medium, !panel { withAnimation(.easeOut(duration: 0.25)) { medium = true } } }
        .accessibilityActions {
            if !medium {
                ForEach(Corner.allCases, id: \.self) { option in
                    Button("Move to \(option.name)") { withAnimation(tileTravel) { corner = option } }
                }
            }
        }
    }

    private var tileLabel: String {
        if meBig { calls.remoteVideo != nil ? "\(partnerName)'s video" : "\(partnerName), camera off" } else { calls.cameraOn ? "Your video" : "You, camera off" }
    }

    private var tileButtons: some View {
        VStack {
            HStack {
                CallControlButton(symbol: "arrow.up.left.and.arrow.down.right", label: meBig ? "Make \(partnerName) big" : "Make my view big", size: 44, action: expand)
                Spacer()
                if !meBig {
                    CallControlButton(symbol: "arrow.triangle.2.circlepath.camera", label: "Flip camera", size: 44) {
                        Task { await calls.flipCamera() }
                    }
                    .accessibilityValue(calls.front ? "Front" : "Back")
                }
            }
            Spacer()
            if !meBig {
                HStack {
                    Spacer()
                    CallControlButton(symbol: "face.smiling", label: "Add stickers", size: 44) {
                        openPanel()
                    }
                    .disabled(!faceAllowed)
                    .accessibilityHint(faceAllowed ? "" : "Turn on your front camera to add stickers")
                }
            }
        }
        .padding(12)
    }

    private var bar: some View {
        HStack(spacing: 0) {
            CallControlButton(symbol: "face.smiling", label: "Stickers", action: openPanel)
            Spacer(minLength: 0)
            CallControlButton(symbol: calls.micOn ? "mic" : "mic.slash", label: calls.micOn ? "Mute" : "Unmute", style: calls.micOn ? .frosted : .active) {
                Task { await calls.toggleMic() }
            }
            .accessibilityValue(calls.micOn ? "" : "Muted")
            Spacer(minLength: 0)
            CallControlButton(symbol: calls.cameraOn ? "video" : "video.slash", label: calls.cameraOn ? "Turn camera off" : "Turn camera on", style: calls.cameraOn ? .frosted : .active) {
                Task { await calls.toggleCamera() }
            }
            .accessibilityValue(calls.cameraOn ? "" : "Camera off")
            Spacer(minLength: 0)
            RouteButton()
            Spacer(minLength: 0)
            CallControlButton(symbol: "phone.down.fill", label: "End call", style: .end) {
                Task { await calls.end() }
            }
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func shrink() {
        withAnimation(.easeOut(duration: 0.2)) { medium = false }
    }

    private func expand() {
        withAnimation(.easeOut(duration: 0.3)) {
            meBig.toggle()
            medium = false
        }
    }

    private func openPanel() {
        scheme = Self.systemScheme
        hovering = false
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.3)) {
            if faceAllowed { meBig = true }
            medium = false
            panel = true
        }
    }

    private func closePanel() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.25)) {
            panel = false
            hovering = false
        }
    }

    private func add(_ kind: Sticker.Kind) {
        if stickers.add(Sticker(kind: kind), at: nil, select: true) { closePanel() }
    }

    private static var systemScheme: ColorScheme {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.screen.traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }
}

struct Frost<S: Shape>: View {
    let shape: S
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if reduceTransparency {
            shape.fill(Color("CallFrost").opacity(0.9))
        } else {
            shape.fill(.ultraThinMaterial).overlay(shape.fill(Color("CallFrost").opacity(0.55)))
        }
    }
}

struct CallControlButton: View {
    enum Style { case frosted, active, end }

    let symbol: String
    let label: String
    var style = Style.frosted
    var size: CGFloat = 56
    var tint = Color("TextPrimary")
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size == 56 ? 26 : 22, weight: .semibold))
                .foregroundStyle(style == .frosted ? tint : Color(style == .active ? "OnAccent" : "OnDanger"))
                .frame(width: size, height: size)
                .background {
                    switch style {
                    case .frosted: Frost(shape: Circle())
                    case .active: Circle().fill(Color("Accent"))
                    case .end: Circle().fill(Color("Danger"))
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(label)
    }
}

struct NamePill: View {
    let name: String
    let start: Date?
    let status: String?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = Duration.seconds(max(0, Int(context.date.timeIntervalSince(start ?? context.date))))
            HStack(spacing: 8) {
                Text(name)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(status ?? elapsed.formatted(.time(pattern: elapsed >= .seconds(3600) ? .hourMinuteSecond : .minuteSecond)))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .opacity(0.85)
                    .fixedSize()
            }
            .foregroundStyle(Color("TextPrimary"))
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(Frost(shape: Capsule()))
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(name)
            .accessibilityValue(status ?? elapsed.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide)))
            .accessibilityAddTraits(.updatesFrequently)
        }
    }
}

struct RouteButton: View {
    @State private var route = Self.current

    var body: some View {
        ZStack {
            Image(systemName: route.symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color("TextPrimary"))
                .frame(width: 56, height: 56)
                .background(Frost(shape: Circle()))
                .accessibilityHidden(true)
            RoutePicker()
                .frame(width: 56, height: 56)
                .accessibilityLabel("Audio output")
                .accessibilityValue(route.name)
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification).receive(on: RunLoop.main)) { _ in
            route = Self.current
        }
    }

    private static var current: (symbol: String, name: String) {
        guard let output = AVAudioSession.sharedInstance().currentRoute.outputs.first else { return ("speaker.wave.2", "Speaker") }
        return switch output.portType {
        case .builtInReceiver: ("iphone", "iPhone")
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE: ("airpods", output.portName)
        case .headphones, .usbAudio: ("headphones", output.portName)
        case .carAudio: ("car", output.portName)
        default: ("speaker.wave.2", "Speaker")
        }
    }

    private struct RoutePicker: UIViewRepresentable {
        func makeUIView(context _: Context) -> AVRoutePickerView {
            let picker = AVRoutePickerView()
            picker.tintColor = .clear
            picker.activeTintColor = .clear
            return picker
        }

        func updateUIView(_: AVRoutePickerView, context _: Context) {}
    }
}

struct Feed: View {
    let track: VideoTrack?
    let profile: Profile?
    var mirror = false
    var preview: CALayer?
    var avatar: CGFloat = 56
    var big = false

    var body: some View {
        if track != nil, let preview {
            LayerView(layer: preview)
        } else if let track {
            SwiftUIVideoView(track, layoutMode: .fill, mirrorMode: mirror ? .mirror : .off)
        } else {
            Color("Background")
                .overlay {
                    VStack(spacing: 14) {
                        Avatar(profile: profile, size: avatar, outline: avatar >= 96 ? 2.5 : 2)
                        if big {
                            VStack(spacing: 6) {
                                Text(profile?.displayName ?? "")
                                    .font(.title2.weight(.heavy))
                                    .foregroundStyle(Color("TextPrimary"))
                                Label("Camera off", systemImage: "video.slash")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color("TextSecondary"))
                            }
                        }
                    }
                }
                .transition(.opacity)
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

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { layer.addSublayer(hosted) }
            setNeedsLayout()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard hosted.superlayer === layer else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            hosted.frame = bounds
            CATransaction.commit()
        }
    }
}

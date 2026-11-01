import ARKit
import ButtercupKit
import SwiftUI

@main
struct ButtercupApp: App {
    @State private var session: SessionStore
    @State private var calls: CallStore
    @State private var stickers: StickerLayer
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let session = SessionStore()
        let calls = CallStore(session: session)
        let stickers = StickerLayer()
        let compositor = stickers.compositor
        #if targetEnvironment(simulator)
        calls.videoSource = { TestClipCapturer.start($0, compositor: compositor) }
        #else
        if ARFaceTrackingConfiguration.isSupported {
            let tracker = ARKitFaceTracker()
            calls.videoSource = { capturer in
                tracker.onFrame = { [weak capturer, weak tracker] buffer, face, time in
                    let buffer = compositor.render(buffer, face: face, camera: tracker?.camera, orientation: .right)
                    capturer?.capture(buffer, timeStampNs: Int64(time * 1_000_000_000), rotation: ._90)
                }
                tracker.start()
            }
            calls.videoStop = tracker.stop
        }
        #endif
        _session = State(initialValue: session)
        _calls = State(initialValue: calls)
        _stickers = State(initialValue: stickers)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch session.state {
                case .loading: ProgressView()
                case .signedOut: SignInView()
                case .needsName: NameView()
                case .unpaired: PairView()
                case .ready: ContentView()
                }
            }
            .environment(session)
            .environment(calls)
            .environment(stickers)
            .onChange(of: calls.phase) { _, phase in
                if phase == .idle { stickers.clear() }
            }
            .onOpenURL { url in Task { await session.openInvite(url) } }
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active {
                    Task {
                        await session.refresh()
                        await calls.resync()
                    }
                }
            }
        }
    }
}

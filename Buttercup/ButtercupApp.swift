import ARKit
import ButtercupKit
import SwiftData
import SwiftUI

@main
struct ButtercupApp: App {
    @State private var session: SessionStore
    @State private var calls: CallStore
    @State private var stickers: StickerLayer
    @State private var notes: NotesStore
    @State private var sounds: SoundsStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearance = "system"

    init() {
        assert(UIFont(name: "Noteworthy-Bold", size: 18) != nil)
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
                    let buffer = compositor.render(buffer, face: face, camera: tracker?.camera, orientation: .right, mirrored: true)
                    capturer?.capture(buffer, timeStampNs: Int64(time * 1_000_000_000))
                }
                tracker.start()
            }
            calls.videoStop = tracker.stop
        }
        #endif
        _session = State(initialValue: session)
        _calls = State(initialValue: calls)
        _stickers = State(initialValue: stickers)
        let container = try! ModelContainer(for: Note.self, OutboxAction.self, configurations: ModelConfiguration(groupContainer: .identifier(Outbox.appGroup)))
        let outbox = Outbox(client: session.client, container: container)
        outbox.onOnline = { Task { await session.refresh() } }
        _notes = State(initialValue: NotesStore(outbox: outbox))
        _sounds = State(initialValue: SoundsStore(client: session.client, outbox: outbox))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch session.state {
                case .loading: ProgressView()
                case .offline:
                    ContentUnavailableView {
                        Label("Couldn't connect", systemImage: "wifi.slash")
                    } actions: {
                        Button("Try again") { Task { await session.refresh() } }
                    }
                case .signedOut: SignInView()
                case .needsName: NameView()
                case .unpaired: PairView()
                case .ready: ContentView()
                }
            }
            .preferredColorScheme(appearance == "light" ? .light : appearance == "dark" ? .dark : nil)
            .environment(session)
            .environment(calls)
            .environment(stickers)
            .onChange(of: calls.phase) { _, phase in
                if phase == .idle { stickers.clear() }
            }
            .environment(notes)
            .environment(sounds)
            .onOpenURL { url in Task { await session.openInvite(url) } }
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active {
                    Task {
                        await session.refresh()
                        await calls.resync()
                        await notes.outbox.flush()
                    }
                }
            }
        }
    }
}

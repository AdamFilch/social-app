import ButtercupKit
import SwiftUI

@main
struct ButtercupApp: App {
    @State private var session: SessionStore
    @State private var calls: CallStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        assert(UIFont(name: "Noteworthy-Bold", size: 18) != nil)
        let session = SessionStore()
        let calls = CallStore(session: session)
        #if targetEnvironment(simulator)
        calls.videoSource = TestClipCapturer.start
        #endif
        _session = State(initialValue: session)
        _calls = State(initialValue: calls)
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

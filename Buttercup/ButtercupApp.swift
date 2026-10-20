import ButtercupKit
import SwiftUI

@main
struct ButtercupApp: App {
    @State private var session = SessionStore()
    @Environment(\.scenePhase) private var scenePhase

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
            .onOpenURL { url in Task { await session.openInvite(url) } }
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active { Task { await session.refresh() } }
            }
        }
    }
}

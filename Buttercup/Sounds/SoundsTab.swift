import ButtercupKit
import SwiftUI

struct SoundsTab: View {
    @Environment(SessionStore.self) private var session
    @Environment(SoundsStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    let soundsChanged: Int
    @State private var sounds: [SoundRecord]?
    @State private var player = SoundPlayer()
    @State private var refresh = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Sounds")
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(Color("TextPrimary"))
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize.isAccessibilitySize ? 2 : 3), spacing: 12) {
                    RecordTile {}
                    ForEach(sounds ?? []) { sound in
                        tile(sound)
                            .transition(.opacity)
                    }
                }
                .padding(.trailing, 3)
                if sounds?.isEmpty == true {
                    VStack(spacing: 6) {
                        Text("No sounds yet. Record one for \(session.partner?.displayName ?? "")?")
                            .font(.headline)
                            .foregroundStyle(Color("TextPrimary"))
                        Text("Up to 10 seconds. Sounds you save show up for you both.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color("TextSecondary"))
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Color("Background"))
        .sensoryFeedback(.error, trigger: player.failures)
        .onAppear { if sounds == nil { sounds = store.cached } }
        .task(id: refresh) { await load() }
        .onChange(of: soundsChanged) { refresh += 1 }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh += 1 } }
    }

    private func tile(_ sound: SoundRecord) -> some View {
        let playing = player.playingID == sound.id
        return TimelineView(.animation(paused: !playing)) { context in
            SoundTile(
                sound: sound,
                progress: playing ? player.progress(at: context.date) : nil,
                loading: player.loadingID == sound.id,
                failed: player.failedID == sound.id
            ) { player.tap(sound, store: store) }
        }
    }

    private func load() async {
        guard let rows = try? await store.sounds() else { return }
        if let id = player.playingID ?? player.loadingID, !rows.contains(where: { $0.id == id }) { player.stop() }
        withAnimation(.easeOut(duration: 0.2)) { sounds = rows }
    }
}

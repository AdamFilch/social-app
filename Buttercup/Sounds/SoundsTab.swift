import ButtercupKit
import SwiftUI

struct SoundsTab: View {
    @Environment(SessionStore.self) private var session
    @Environment(SoundsStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    let soundsChanged: Int
    @Binding var recordOpen: Bool
    @Binding var deleting: SoundRecord?
    @State private var sounds: [SoundRecord]?
    @State private var editing: SoundRecord?
    @State private var dragging: UUID?
    @State private var dragLive = false
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
                    RecordTile(sticker: !recordOpen && deleting == nil) { recordOpen = true }
                        .onDrop(of: [.text], delegate: TileDrop(target: nil, sounds: $sounds, dragging: dragging, begin: { dragLive = true }, commit: commit))
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
        .onDrop(of: [.text], delegate: TileDrop(target: nil, reorders: false, sounds: $sounds, dragging: dragging, begin: { dragLive = true }, commit: commit))
        .sheet(item: $editing) { EditSoundSheet(sound: $0) }
        .sensoryFeedback(.error, trigger: player.failures)
        .onAppear { if sounds == nil { sounds = store.all } }
        .task(id: refresh) { await load() }
        .onChange(of: store.all) { _, rows in if let rows { show(rows) } }
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
                failed: player.failedID == sound.id,
                slot: dragLive && dragging == sound.id
            ) { player.tap(sound, store: store) }
        }
        .accessibilityAction(named: "Edit") { editing = sound }
        .accessibilityAction(named: "Delete") { deleting = sound }
        .accessibilityAction(named: "Move earlier") { move(sound, by: -1) }
        .accessibilityAction(named: "Move later") { move(sound, by: 1) }
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contextMenu {
            Button("Edit", systemImage: "pencil") { dragging = nil; editing = sound }
            Button("Delete", systemImage: "trash", role: .destructive) { dragging = nil; deleting = sound }
        }
        .onDrag {
            player.stop()
            dragLive = false
            dragging = sound.id
            let provider = DragProvider(object: sound.id.uuidString as NSString)
            provider.onEnd = endDrag
            return provider
        } preview: {
            SoundTile(sound: sound, progress: nil) {}
                .frame(width: 116, height: 108)
        }
        .onDrop(of: [.text], delegate: TileDrop(target: sound.id, sounds: $sounds, dragging: dragging, begin: { dragLive = true }, commit: commit))
    }

    private func move(_ sound: SoundRecord, by offset: Int) {
        guard var ids = sounds?.map(\.id), let from = ids.firstIndex(of: sound.id), ids.indices.contains(from + offset) else { return }
        ids.swapAt(from, from + offset)
        store.reorder(ids)
    }

    private func endDrag() {
        guard dragging != nil else { return }
        dragging = nil
        dragLive = false
        if let rows = store.all { withAnimation(.easeOut(duration: 0.2)) { sounds = rows } }
    }

    private func commit() {
        guard dragging != nil else { return }
        let live = dragLive
        dragging = nil
        dragLive = false
        guard live else { return }
        guard let ids = sounds?.map(\.id) else { return }
        if ids != store.all?.map(\.id) { store.reorder(ids) }
    }

    private func load() async {
        guard let rows = try? await store.sounds() else { return }
        show(store.all ?? rows)
    }

    private func show(_ incoming: [SoundRecord]) {
        var rows = incoming
        if dragLive, let local = sounds?.map(\.id) {
            let rank = Dictionary(local.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
            rows = rows.filter { rank[$0.id] == nil } + rows.filter { rank[$0.id] != nil }.sorted { rank[$0.id]! < rank[$1.id]! }
        } else {
            dragging = nil
        }
        if let id = player.playingID ?? player.loadingID, !rows.contains(where: { $0.id == id }) { player.stop() }
        if let editing, !rows.contains(where: { $0.id == editing.id }) { self.editing = nil }
        if let deleting, !rows.contains(where: { $0.id == deleting.id }) { self.deleting = nil }
        withAnimation(.easeOut(duration: 0.2)) { sounds = rows }
    }
}

private struct TileDrop: DropDelegate {
    let target: UUID?
    var reorders = true
    @Binding var sounds: [SoundRecord]?
    let dragging: UUID?
    let begin: () -> Void
    let commit: () -> Void

    func dropEntered(info: DropInfo) {
        if dragging != nil { begin() }
        guard reorders, let dragging, var list = sounds, let from = list.firstIndex(where: { $0.id == dragging }) else { return }
        let to = target.flatMap { id in list.firstIndex { $0.id == id } } ?? 0
        guard from != to else { return }
        list.move(fromOffsets: [from], toOffset: to > from ? to + 1 : to)
        withAnimation(.easeOut(duration: 0.2)) { sounds = list }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if dragging != nil { begin() }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        let wasDragging = dragging != nil
        commit()
        return wasDragging
    }
}

private final class DragProvider: NSItemProvider {
    var onEnd: (@MainActor () -> Void)?

    deinit {
        let end = onEnd
        Task { @MainActor in end?() }
    }
}

struct DeleteSoundCard: View {
    let sound: SoundRecord
    let close: () -> Void
    @Environment(SoundsStore.self) private var store
    @Environment(SessionStore.self) private var session
    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Delete “\(sound.title)”?")
                .font(.title3.weight(.heavy))
                .foregroundStyle(Color("TextPrimary"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($titleFocused)
            Text("It goes for both of you. \(session.partner?.displayName ?? "Your partner") won't have it either.")
                .font(.body)
                .foregroundStyle(Color("TextPrimary"))
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 12) {
                Button(action: close) { Text("Keep it").frame(maxWidth: .infinity) }
                Button {
                    store.delete(sound)
                    close()
                } label: {
                    Label("Delete", systemImage: "trash")
                        .foregroundStyle(Color("Danger"))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(PillButtonStyle(kind: .secondary))
        }
        .task { titleFocused = true }
    }
}

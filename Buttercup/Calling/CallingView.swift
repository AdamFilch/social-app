import ButtercupKit
import SwiftUI

struct CallingView: View {
    @Environment(SessionStore.self) private var session
    @Environment(CallStore.self) private var calls
    @Environment(NotesStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    let onSent: (NoteSendResult) -> Void
    @Binding var open: OpenNotes?
    let notesChanged: Int
    @AppStorage("lastSeenNoteID") private var lastSeenNoteID = ""
    @State private var latest: OpenNotes?
    @State private var isComposing = false
    @State private var sent: NoteSendResult?

    private var name: String { session.partner?.displayName ?? "" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleRow
                partnerCard
                if let latest, let note = latest.notes.first(where: { $0.id == latest.current }) {
                    noteCard(note)
                }
                if let history = calls.history {
                    recentCalls(history)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Color("Background"))
        .fullScreenCover(isPresented: $isComposing) {
            if let sent { onSent(sent) }
            sent = nil
        } content: {
            NewNoteView(partnerName: name) { sent = $0 }
        }
        .task { await calls.loadHistory() }
        .task(id: notesChanged) { await loadLatest() }
    }

    private var titleRow: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout())
        return layout {
            HStack(spacing: 6) {
                Text("Calling")
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(Color("TextPrimary"))
                    .accessibilityAddTraits(.isHeader)
                if calls.history?.isEmpty != true {
                    Doodle(name: "doodle-flower")
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            Text(Date.now, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("TextSecondary"))
        }
    }

    private var partnerCard: some View {
        let pair = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Avatar(profile: session.partner, size: 56, outline: 2.5)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.headline)
                        .foregroundStyle(Color("TextPrimary"))
                    Text(lastCall)
                        .font(.subheadline)
                        .foregroundStyle(Color("TextSecondary"))
                }
            }
            .accessibilityElement(children: .combine)
            pair {
                Button {
                    Task { await calls.startCall(video: false) }
                } label: {
                    Label("Audio", systemImage: "phone.fill").frame(maxWidth: .infinity)
                }
                Button {
                    Task { await calls.startCall(video: true) }
                } label: {
                    Label("Video", systemImage: "video.fill").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(PillButtonStyle(height: 56))
            .disabled(calls.phase != .idle || session.partner == nil)
        }
        .card()
    }

    private func noteCard(_ note: NoteRecord) -> some View {
        let unseen = note.id.uuidString != lastSeenNoteID
        let ago = note.createdAt.formatted(.relative(presentation: .named))
        let row = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14)) : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
        return row {
            Button {
                lastSeenNoteID = note.id.uuidString
                open = latest
            } label: {
                NoteImage(note: note)
                    .frame(width: 112, height: 112)
                    .clipShape(.rect(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color("Outline"), lineWidth: 2.5))
                    .overlay {
                        ZStack {
                            RoundedRectangle(cornerRadius: 23).strokeBorder(Color("Background"), lineWidth: 3).padding(-3)
                            RoundedRectangle(cornerRadius: 26).strokeBorder(Color("Highlight"), lineWidth: 3).padding(-6)
                        }
                        .opacity(unseen ? 1 : 0)
                        .animation(.easeOut(duration: 0.15), value: unseen)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(unseen ? "New note" : "Note") from \(name), \(ago)")
            .accessibilityHint("Opens the note")
            VStack(alignment: .leading, spacing: 4) {
                if unseen {
                    Text("New")
                        .font(.caption.bold())
                        .foregroundStyle(Color("OnHighlight"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color("Highlight")))
                        .overlay(Capsule().strokeBorder(Color("Outline"), lineWidth: 2))
                        .accessibilityHidden(true)
                }
                Text("Note from \(name)")
                    .font(.headline)
                    .foregroundStyle(Color("TextPrimary"))
                Text(ago)
                    .font(.subheadline)
                    .foregroundStyle(Color("TextSecondary"))
                Button {
                    isComposing = true
                } label: {
                    Label("Send one back", systemImage: "pencil.tip")
                        .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil)
                }
                .buttonStyle(PillButtonStyle(kind: .secondary, size: .small))
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func recentCalls(_ history: [Call]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent calls")
                .font(.title3.weight(.heavy))
                .foregroundStyle(Color("TextPrimary"))
                .accessibilityAddTraits(.isHeader)
            if history.isEmpty {
                VStack(spacing: 6) {
                    Doodle(name: "doodle-flower")
                    Text("No calls yet")
                        .font(.headline)
                        .foregroundStyle(Color("TextPrimary"))
                    Text("Give \(name) a ring?")
                        .font(.footnote)
                        .foregroundStyle(Color("TextSecondary"))
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .card()
            } else {
                VStack(spacing: 0) {
                    ForEach(history) { call in
                        CallRow(call: call)
                        if call.id != history.last?.id {
                            Rectangle().fill(Color("Divider")).frame(height: 1.5)
                        }
                    }
                }
                .card(padding: 0)
            }
        }
        .padding(.top, 8)
    }

    private var lastCall: String {
        guard let history = calls.history else { return "" }
        guard let call = history.first else { return "No calls yet" }
        let day = Self.day(call.createdAt)
        let relative = Calendar.current.isDateInToday(call.createdAt) || Calendar.current.isDateInYesterday(call.createdAt) ? day.lowercased() : day
        if call.status == "missed" { return "Missed call \(relative)" }
        if let duration = call.duration { return "Last call \(relative) · \(Self.minutes(duration))" }
        return "Last call \(relative)"
    }

    static func day(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    static func minutes(_ duration: TimeInterval) -> String {
        "\(max(1, Int((duration / 60).rounded()))) min"
    }

    private func loadLatest() async {
        let calendar = NotesTab.calendar
        let today = calendar.startOfDay(for: .now)
        guard let start = calendar.date(byAdding: .day, value: -30, to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today),
              let rows = try? await store.notes(in: DateInterval(start: start, end: end)) else { return }
        guard let note = rows.first(where: { $0.senderId == session.partner?.id }) else {
            latest = nil
            return
        }
        latest = OpenNotes(notes: rows.filter { calendar.isDate($0.createdAt, inSameDayAs: note.createdAt) }, current: note.id)
    }
}

struct CallRow: View {
    let call: Call
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let missed = call.status == "missed"
        HStack(spacing: 12) {
            Image(systemName: missed ? "phone.down" : call.isVideo ? "video" : "phone")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color(missed ? "Danger" : "TextPrimary"))
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color("Background")))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color("Outline"), lineWidth: 2))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(call.isVideo ? "Video call" : "Audio call")
                    .font(.headline)
                    .foregroundStyle(Color("TextPrimary"))
                subtitle.font(.subheadline)
                if typeSize.isAccessibilitySize { time }
            }
            Spacer(minLength: 8)
            if !typeSize.isAccessibilitySize { time }
        }
        .padding(.vertical, 6)
        .frame(minHeight: 62)
        .accessibilityElement(children: .combine)
    }

    private var time: some View {
        Text(call.createdAt, format: .dateTime.hour().minute())
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(Color("TextSecondary"))
    }

    @ViewBuilder private var subtitle: some View {
        switch call.status {
        case "missed": Text("Missed").bold().foregroundStyle(Color("Danger"))
        case "declined": Text("Declined").foregroundStyle(Color("TextSecondary"))
        case "cancelled": Text("Cancelled").foregroundStyle(Color("TextSecondary"))
        default:
            Text([CallingView.day(call.createdAt), call.duration.map(CallingView.minutes)].compactMap(\.self).joined(separator: " · "))
                .foregroundStyle(Color("TextSecondary"))
        }
    }
}

private extension View {
    func card(padding: CGFloat = 16) -> some View {
        self
            .padding(.vertical, padding)
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color("Surface")))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color("Outline"), lineWidth: 2.5))
    }
}

struct Avatar: View {
    let profile: Profile?
    var size: CGFloat = 64
    var outline: CGFloat = 0

    var body: some View {
        Text(profile?.displayName.prefix(1).uppercased() ?? "")
            .font(.system(size: size * 0.42, weight: .heavy))
            .foregroundStyle(Color("OnAccent"))
            .frame(width: size, height: size)
            .background(Color(profile?.avatarTint ?? "NotePaperYellow"), in: .circle)
            .overlay(Circle().strokeBorder(Color("Outline"), lineWidth: outline))
    }
}

import ButtercupKit
import SwiftUI

struct OpenNotes {
    var notes: [NoteRecord]
    var current: UUID
}

struct NoteDialog: View {
    @Environment(SessionStore.self) private var session
    let notes: [NoteRecord]
    @Binding var current: UUID
    let close: () -> Void
    @AccessibilityFocusState private var nameFocused: Bool

    var body: some View {
        let index = notes.firstIndex { $0.id == current } ?? 0
        let note = notes.indices.contains(index) ? notes[index] : nil
        let mine = note?.senderId == session.me?.id
        let name = mine ? "You" : session.partner?.displayName ?? ""
        HStack(spacing: 12) {
            Avatar(profile: mine ? session.me : session.partner, size: 40)
                .overlay(Circle().strokeBorder(Color("Outline"), lineWidth: 2.5))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(Color("TextPrimary"))
                if let note {
                    Text("\(note.createdAt.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))) · \(note.createdAt.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(Color("TextSecondary"))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityFocused($nameFocused)
            Spacer(minLength: 0)
            IconCircleButton(symbol: "xmark", label: "Close", action: close)
        }
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(notes) { NoteImage(note: $0).containerRelativeFrame(.horizontal) }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: Binding(get: { current }, set: { if let id = $0 { current = id } }))
            .onAppear { proxy.scrollTo(current) }
            .onChange(of: notes.map(\.id)) { proxy.scrollTo(current) }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color("Outline"), lineWidth: 2.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(note.map { "Note from \(mine ? "you" : name), \($0.createdAt.formatted(.dateTime.weekday(.wide).day().month(.wide))), \($0.createdAt.formatted(date: .omitted, time: .shortened)), note \(index + 1) of \(notes.count)" } ?? "")
        .accessibilityAdjustableAction { direction in
            let next = direction == .increment ? index + 1 : index - 1
            if notes.indices.contains(next) { current = notes[next].id }
        }
        .onAppear { nameFocused = true }
        if notes.count > 1 {
            HStack(spacing: 8) {
                ForEach(notes) { item in
                    Circle()
                        .fill(Color(item.id == current ? "Outline" : "Divider"))
                        .overlay(Circle().strokeBorder(Color("Outline"), lineWidth: 1.5))
                        .frame(width: 8, height: 8)
                }
            }
            .accessibilityHidden(true)
        }
    }
}

import ButtercupKit
import SwiftUI

struct DayGrid: View {
    static func count(_ count: Int) -> String {
        count == 0 ? "No notes" : count == 1 ? "1 note" : "\(count) notes"
    }

    let day: Date
    let notes: [NoteRecord]?
    let failed: Bool
    let retry: () -> Void
    @Binding var open: OpenNotes?
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showsSpinner = false

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(day, format: .dateTime.weekday(.wide).day())
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Color("TextPrimary"))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let notes {
                    Text(Self.count(notes.count))
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(Color("TextSecondary"))
                }
            }
            .padding(.horizontal, 20)
            ScrollView {
                content
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .onChange(of: notes?.map(\.id)) {
            guard let notes, let current = open?.current else { return }
            if notes.contains(where: { $0.id == current }) { open?.notes = notes } else { open = nil }
        }
    }

    @ViewBuilder private var content: some View {
        if failed {
            VStack(spacing: 14) {
                Text("Couldn't load notes. Try again")
                    .font(.body)
                    .foregroundStyle(Color("TextSecondary"))
                Button("Try again", action: retry)
                    .buttonStyle(PillButtonStyle(kind: .secondary, height: 40))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 56)
        } else if let notes {
            if notes.isEmpty {
                Text("No notes yet")
                    .font(.headline)
                    .foregroundStyle(Color("TextSecondary"))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 56)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 16) {
                    ForEach(notes) { note in
                        Button { open = OpenNotes(notes: notes, current: note.id) } label: { NoteTile(note: note) }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens the note")
                    }
                }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 56)
                .opacity(showsSpinner ? 1 : 0)
                .task {
                    try? await Task.sleep(for: .seconds(1))
                    showsSpinner = true
                }
        }
    }
}

struct NoteTile: View {
    @Environment(SessionStore.self) private var session
    let note: NoteRecord

    var body: some View {
        let mine = note.senderId == session.me?.id
        NoteImage(note: note)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color("Outline"), lineWidth: 2.5))
            .overlay(alignment: .bottomLeading) {
                Avatar(profile: mine ? session.me : session.partner, size: 24)
                    .overlay(Circle().strokeBorder(Color("Outline"), lineWidth: 2))
                    .padding(8)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Note from \(mine ? "you" : session.partner?.displayName ?? ""), \(note.createdAt.formatted(date: .omitted, time: .shortened))")
    }
}

struct NoteImage: View {
    @Environment(NotesStore.self) private var store
    let note: NoteRecord
    var glyph = true
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Color("Divider")
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else if failed && glyph {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Color("TextSecondary"))
                }
            }
            .clipped()
            .task(id: note.id) {
                let loaded = await store.image(for: note)
                withAnimation(.easeOut(duration: 0.15)) {
                    image = loaded
                    failed = loaded == nil
                }
            }
    }
}

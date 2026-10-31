import ButtercupKit
import SwiftUI

struct NotesTab: View {
    static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        return calendar
    }

    @Environment(SessionStore.self) private var session
    @Environment(NotesStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    let onSent: (NoteSendResult) -> Void
    @Binding var open: OpenNotes?
    @State private var isComposing = false
    @State private var sent: NoteSendResult?
    @State private var today = Self.calendar.startOfDay(for: .now)
    @State private var selectedDay = Self.calendar.startOfDay(for: .now)
    @State private var loaded: [Date: [NoteRecord]] = [:]
    @State private var failedWeek: Date?
    @State private var refresh = 0

    var body: some View {
        let week = Self.weekStart(selectedDay)
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                Text("Notes")
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(Color("TextPrimary"))
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                Button {
                    isComposing = true
                } label: {
                    Label("Make a note", systemImage: "pencil.tip").frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle(height: 56, sticker: true))
                .padding(.trailing, 3)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 15)
            WeekStrip(
                weeks: weeks,
                today: today,
                notes: loaded.filter { $0.key != failedWeek },
                selectedDay: $selectedDay
            )
            DayGrid(
                day: selectedDay,
                notes: failedWeek == week ? nil : loaded[week].map { $0.filter { Self.calendar.isDate($0.createdAt, inSameDayAs: selectedDay) } },
                failed: failedWeek == week,
                retry: { refresh += 1 },
                open: $open
            )
            .id(selectedDay)
            .transition(.opacity)
            .padding(.top, 9)
        }
        .padding(.top, 4)
        .background(Color("Background"))
        .fullScreenCover(isPresented: $isComposing) {
            if let sent {
                onSent(sent)
                refresh += 1
            }
            sent = nil
        } content: {
            NewNoteView(partnerName: session.partner?.displayName ?? "") { sent = $0 }
        }
        .task(id: [week, refresh] as [AnyHashable]) { await load(week) }
        .task {
            for await _ in store.changes() { refresh += 1 }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            let now = Self.calendar.startOfDay(for: .now)
            if now != today {
                if selectedDay == today { selectedDay = now }
                today = now
            }
            refresh += 1
        }
    }

    private var weeks: [Date] {
        let first = Self.weekStart(session.pairedAt ?? today)
        let last = Self.weekStart(today)
        let count = Self.calendar.dateComponents([.weekOfYear], from: first, to: last).weekOfYear ?? 0
        return (0...max(count, 0)).compactMap { Self.calendar.date(byAdding: .weekOfYear, value: $0, to: first) }
    }

    static func weekStart(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    private func load(_ week: Date) async {
        guard let end = Self.calendar.date(byAdding: .weekOfYear, value: 1, to: week) else { return }
        do {
            let rows = try await store.notes(in: DateInterval(start: week, end: end))
            withAnimation(.easeOut(duration: 0.15)) {
                loaded[week] = rows
                failedWeek = nil
            }
        } catch {
            if !Task.isCancelled { failedWeek = week }
        }
    }
}

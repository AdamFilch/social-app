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
    @Environment(\.dynamicTypeSize) private var typeSize
    let onSent: (NoteSendResult) -> Void
    @Binding var open: OpenNotes?
    @State private var isComposing = false
    @State private var sent: NoteSendResult?
    @State private var today = Self.calendar.startOfDay(for: .now)
    @State private var selectedDay = Self.calendar.startOfDay(for: .now)
    @State private var loaded: [Date: [NoteRecord]] = [:]
    @State private var failedWeek: Date?
    @State private var refresh = 0
    @State private var showsMonth = false
    @State private var visibleMonth = Self.monthStart(.now)
    @State private var monthNotes: [Date: [NoteRecord]] = [:]

    var body: some View {
        let week = Self.weekStart(selectedDay)
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                let titleRow = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())
                titleRow {
                    Text("Notes")
                        .font(.largeTitle.weight(.heavy))
                        .foregroundStyle(Color("TextPrimary"))
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    Button(action: toggle) {
                        HStack(spacing: 6) {
                            Image(systemName: showsMonth ? "calendar.day.timeline.left" : "calendar")
                                .font(.system(size: 18, weight: .semibold))
                            Text(showsMonth ? "Current week" : selectedDay.formatted(.dateTime.month(.wide)))
                        }
                        .id(showsMonth)
                        .transition(.opacity)
                    }
                    .buttonStyle(PillButtonStyle(kind: .secondary, size: .small))
                    .accessibilityLabel(showsMonth ? "Show current week" : "Show month, \(selectedDay.formatted(.dateTime.month(.wide)))")
                }
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
            if showsMonth {
                ScrollView {
                    MonthCalendar(
                        months: months,
                        weeks: (weeks.first ?? today)...(weeks.last ?? today),
                        today: today,
                        notes: monthNotes,
                        myID: session.me?.id,
                        partnerName: session.partner?.displayName ?? "",
                        month: $visibleMonth
                    ) { day in
                        withAnimation(.easeOut(duration: 0.18)) {
                            selectedDay = day
                            showsMonth = false
                        }
                    }
                    .padding(.top, 5)
                    .padding(.bottom, 24)
                }
                .scrollBounceBehavior(.basedOnSize)
                .transition(.opacity)
            } else {
                VStack(spacing: 0) {
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
                .transition(.opacity)
            }
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
        .task(id: [showsMonth, showsMonth ? visibleMonth : week, refresh] as [AnyHashable]) {
            if showsMonth { await loadMonth(visibleMonth) } else { await load(week) }
        }
        .task {
            for await _ in store.changes() { refresh += 1 }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            let now = Self.calendar.startOfDay(for: .now)
            if now != today {
                if selectedDay == today && (!showsMonth || visibleMonth == Self.monthStart(today)) {
                    selectedDay = now
                    showsMonth = false
                }
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

    private var months: [Date] {
        let first = Self.monthStart(session.pairedAt ?? today)
        let count = Self.calendar.dateComponents([.month], from: first, to: Self.monthStart(today)).month ?? 0
        return (0...max(count, 0)).compactMap { Self.calendar.date(byAdding: .month, value: $0, to: first) }
    }

    static func weekStart(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    static func monthStart(_ date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? date
    }

    private func toggle() {
        withAnimation(.easeOut(duration: 0.18)) {
            if showsMonth {
                selectedDay = today
                showsMonth = false
            } else {
                visibleMonth = Self.monthStart(selectedDay)
                showsMonth = true
            }
        }
    }

    private func loadMonth(_ month: Date) async {
        let days = MonthCalendar.days(of: month)
        guard let first = days.first, let last = days.last,
              let end = Self.calendar.date(byAdding: .day, value: 1, to: last) else { return }
        guard let rows = try? await store.notes(in: DateInterval(start: first, end: end)) else { return }
        withAnimation(.easeOut(duration: 0.15)) { monthNotes[month] = rows }
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

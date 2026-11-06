import ButtercupKit
import SwiftUI

struct WeekStrip: View {
    let weeks: [Date]
    let today: Date
    let notes: [Date: [NoteRecord]]
    @Binding var selectedDay: Date
    @State private var scrolledWeek: Date?

    private var calendar: Calendar { NotesTab.calendar }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(weeks, id: \.self) { week in
                    HStack(spacing: 6) {
                        ForEach(days(of: week), id: \.self) { day in
                            cell(day, notes: dayNotes(day, week: week))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 5)
                    .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .fixedSize(horizontal: false, vertical: true)
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $scrolledWeek)
        .onScrollPhaseChange { _, phase in
            guard phase == .idle, let scrolledWeek else { return }
            let current = NotesTab.weekStart(selectedDay)
            guard scrolledWeek != current,
                  let offset = calendar.dateComponents([.day], from: current, to: selectedDay).day,
                  let day = calendar.date(byAdding: .day, value: offset, to: scrolledWeek) else { return }
            select(day)
        }
        .onAppear { scrolledWeek = NotesTab.weekStart(selectedDay) }
        .onChange(of: selectedDay) { _, day in
            let week = NotesTab.weekStart(day)
            if scrolledWeek != week { scrolledWeek = week }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .background {
            Color.clear
                .accessibilityElement()
                .accessibilityLabel("Week of \(NotesTab.weekStart(selectedDay).formatted(.dateTime.day().month(.wide)))")
                .accessibilityValue(label(selectedDay, notes: dayNotes(selectedDay, week: NotesTab.weekStart(selectedDay))))
                .accessibilityAdjustableAction { direction in
                    let step = direction == .increment ? 1 : -1
                    if let day = calendar.date(byAdding: .day, value: step, to: selectedDay), inRange(day) { select(day) }
                }
                .accessibilityActions {
                    if let day = shifted(by: -1) { Button("Previous week") { select(day) } }
                    if let day = shifted(by: 1) { Button("Next week") { select(day) } }
                }
                .accessibilitySortPriority(1)
        }
        .accessibilityElement(children: .contain)
    }

    private func cell(_ day: Date, notes: [NoteRecord]?) -> some View {
        let isToday = day == today
        let isSelected = day == selectedDay
        let ink = Color(isToday ? "OnAccent" : "TextPrimary")
        return Button {
            select(day)
        } label: {
            VStack(spacing: 2) {
                Text(day, format: .dateTime.weekday(.narrow))
                    .font(.caption.bold())
                    .foregroundStyle(isToday ? ink : Color("TextSecondary"))
                Text(day, format: .dateTime.day())
                    .font(.headline.bold())
                    .monospacedDigit()
                    .foregroundStyle(ink)
                ZStack(alignment: .bottomLeading) {
                    ForEach(Array((notes ?? []).prefix(3).enumerated().reversed()), id: \.element.id) { index, note in
                        NoteImage(note: note, glyph: false)
                            .frame(width: 15, height: 15)
                            .clipShape(.rect(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(isToday ? "OnAccent" : "Outline"), lineWidth: 1.5))
                            .offset(x: 2.5 * CGFloat(index), y: -1.5 * CGFloat(index))
                    }
                }
                .frame(width: 20, height: 18, alignment: .bottomLeading)
            }
            .padding(.top, 6)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .top)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(isToday ? "Accent" : "Surface")))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color("Outline"), lineWidth: 2))
            .overlay {
                RoundedRectangle(cornerRadius: 18.5)
                    .strokeBorder(Color("Outline"), lineWidth: 2.5)
                    .padding(-4.5)
                    .opacity(isSelected ? 1 : 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityShowsLargeContentViewer {
            Text(label(day, notes: notes))
        }
        .accessibilityLabel(label(day, notes: notes))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func days(of week: Date) -> [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week) }
    }

    private func dayNotes(_ day: Date, week: Date) -> [NoteRecord]? {
        notes[week]?.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }
    }

    private func label(_ day: Date, notes: [NoteRecord]?) -> String {
        var parts = [day.formatted(.dateTime.weekday(.wide).day().month(.wide))]
        if day == today { parts.append("today") }
        if let notes { parts.append(DayGrid.count(notes.count).lowercased()) }
        return parts.joined(separator: ", ")
    }

    private func inRange(_ day: Date) -> Bool {
        guard let first = weeks.first, let last = weeks.last,
              let end = calendar.date(byAdding: .weekOfYear, value: 1, to: last) else { return false }
        return day >= first && day < end
    }

    private func shifted(by weeks: Int) -> Date? {
        guard let day = calendar.date(byAdding: .weekOfYear, value: weeks, to: selectedDay), inRange(day) else { return nil }
        return day
    }

    private func select(_ day: Date) {
        withAnimation(.easeOut(duration: 0.15)) { selectedDay = day }
    }
}

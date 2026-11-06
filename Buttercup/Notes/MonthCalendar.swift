import ButtercupKit
import SwiftUI

struct MonthCalendar: View {
    static func days(of month: Date) -> [Date] {
        let calendar = NotesTab.calendar
        guard let next = calendar.date(byAdding: .month, value: 1, to: month),
              let last = calendar.date(byAdding: .day, value: -1, to: next) else { return [] }
        let first = NotesTab.weekStart(month)
        let count = (calendar.dateComponents([.day], from: first, to: NotesTab.weekStart(last)).day ?? 0) + 7
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }

    let months: [Date]
    let weeks: ClosedRange<Date>
    let today: Date
    let notes: [Date: [NoteRecord]]
    let myID: UUID?
    let partnerName: String
    @Binding var month: Date
    let onSelect: (Date) -> Void
    @State private var scrolledMonth: Date?
    @Environment(\.dynamicTypeSize) private var typeSize

    private var calendar: Calendar { NotesTab.calendar }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            pager
            if let rows = notes[month] {
                summary(month, notes: rows.filter { calendar.isDate($0.createdAt, equalTo: month, toGranularity: .month) })
                    .padding(.horizontal, 20)
            }
        }
    }

    private var pager: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 0) {
                ForEach(months, id: \.self) { month in
                    page(month)
                        .padding(.horizontal, 20)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .fixedSize(horizontal: false, vertical: true)
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $scrolledMonth)
        .onScrollPhaseChange { _, phase in
            guard phase == .idle, let scrolledMonth, scrolledMonth != month else { return }
            month = scrolledMonth
        }
        .onAppear { scrolledMonth = month }
        .onChange(of: month) { _, month in
            if scrolledMonth != month { scrolledMonth = month }
        }
    }

    private func page(_ month: Date) -> some View {
        let days = Self.days(of: month)
        let rows = notes[month]
        return VStack(alignment: .leading, spacing: 6) {
            Text(month, format: .dateTime.month(.wide).year())
                .font(.title3.weight(.heavy))
                .foregroundStyle(Color("TextPrimary"))
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
                .accessibilityAddTraits(.isHeader)
                .accessibilityActions { actions(month) }
            Grid(horizontalSpacing: 2, verticalSpacing: 4) {
                GridRow {
                    ForEach(days.prefix(7), id: \.self) { day in
                        Text(day, format: .dateTime.weekday(.narrow))
                            .font(.caption.bold())
                            .foregroundStyle(Color("TextSecondary"))
                            .frame(maxWidth: .infinity, minHeight: 18)
                            .accessibilityHidden(true)
                    }
                }
                ForEach(0..<days.count / 7, id: \.self) { row in
                    GridRow {
                        ForEach(days[row * 7..<row * 7 + 7], id: \.self) { day in
                            cell(day, month: month, notes: rows)
                        }
                    }
                }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .padding(.top, 14)
        .padding([.horizontal, .bottom], 10)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color("Surface")))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color("Outline"), lineWidth: 2.5))
    }

    private func cell(_ day: Date, month: Date, notes: [NoteRecord]?) -> some View {
        let isToday = day == today
        let spill = !calendar.isDate(day, equalTo: month, toGranularity: .month)
        let tappable = weeks.contains(NotesTab.weekStart(day))
        let dayNotes = notes?.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }
        let mine = dayNotes?.contains { $0.senderId == myID } ?? false
        let partner = dayNotes?.contains { $0.senderId != myID } ?? false
        let label = label(day, mine: mine, partner: partner, loaded: dayNotes != nil)
        return VStack(spacing: 5) {
            Text(day, format: .dateTime.day())
                .font(.headline.weight(spill ? .semibold : .bold))
                .monospacedDigit()
                .foregroundStyle(Color(isToday ? "OnAccent" : spill ? "TextSecondary" : "TextPrimary"))
            DayDots(mine: mine, partner: partner, onAccent: isToday)
        }
        .padding(.top, 6)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .top)
        .background {
            if isToday {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color("Accent"))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color("Outline"), lineWidth: 2))
            }
        }
        .opacity(spill ? 0.5 : 1)
        .contentShape(.rect)
        .onTapGesture { if tappable { onSelect(day) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(tappable ? .isButton : [])
        .accessibilityShowsLargeContentViewer { Text(label) }
        .accessibilityActions { actions(month) }
    }

    @ViewBuilder private func actions(_ month: Date) -> some View {
        if let index = months.firstIndex(of: month) {
            if index > 0 { Button("Previous month") { self.month = months[index - 1] } }
            if index < months.count - 1 { Button("Next month") { self.month = months[index + 1] } }
        }
    }

    private func label(_ day: Date, mine: Bool, partner: Bool, loaded: Bool) -> String {
        var parts = [day.formatted(.dateTime.weekday(.wide).day().month(.wide))]
        if day == today { parts.append("today") }
        if loaded {
            parts.append(mine && partner ? "notes from you and \(partnerName)" : mine ? "notes from you" : partner ? "notes from \(partnerName)" : "no notes")
        }
        return parts.joined(separator: ", ")
    }

    private func summary(_ month: Date, notes: [NoteRecord]) -> some View {
        let mine = notes.filter { $0.senderId == myID }.count
        let partner = notes.count - mine
        let span = calendar.isDate(month, equalTo: today, toGranularity: .month) ? "this month" : "in \(month.formatted(.dateTime.month(.wide)))"
        let total = "\(DayGrid.count(notes.count)) \(span)"
        let legend = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 16))
        return VStack(alignment: .leading, spacing: 4) {
            Text(total)
                .font(.subheadline.bold())
                .foregroundStyle(Color("TextPrimary"))
            legend {
                HStack(spacing: 6) {
                    DayDots.Dot(colour: "NoteDotMine", size: 10)
                    Text("\(mine) from you")
                }
                HStack(spacing: 6) {
                    DayDots.Dot(colour: "NoteDotPartner", size: 10)
                    Text("\(partner) from \(partnerName)")
                }
            }
            .font(.subheadline.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(Color("TextSecondary"))
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(total), \(mine) from you, \(partner) from \(partnerName)")
    }
}

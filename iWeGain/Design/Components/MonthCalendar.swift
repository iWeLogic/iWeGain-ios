import SwiftUI

/// Dot under a calendar day (Figma "Calendar Day" Mark).
enum DayMark: Equatable { case none, completed, scheduled }

/// One cell of the month grid. [inMonth] false renders it muted (leading/trailing days of other months).
struct CalendarDayUi: Identifiable, Equatable {
    let date: Day
    let inMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let mark: DayMark

    var id: Day { date }
}

/// Month card: navigation, weekday header, 7-column day grid and the dot legend.
struct MonthCalendar: View {
    let title: String
    let weekdayLabels: [String]
    let weeks: [[CalendarDayUi]]
    let onPreviousTap: () -> Void
    let onNextTap: () -> Void
    let onDayTap: (Day) -> Void

    var body: some View {
        VStack(spacing: Spacing.x4) {
            HStack {
                NavButton(icon: "ic_chevron_left", label: "calendar_previous_month", action: onPreviousTap)
                Spacer()
                Text(title).textStyle(.headline).foregroundStyle(Color.textPrimary)
                Spacer()
                NavButton(icon: "ic_chevron_right", label: "calendar_next_month", action: onNextTap)
            }
            .padding(.horizontal, Spacing.x8)
            .padding(.bottom, Spacing.x8)
            HStack(spacing: 0) {
                ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { _, label in
                    Text(label)
                        .textStyle(.caption)
                        .foregroundStyle(Color.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 20, alignment: .top)
                }
            }
            .accessibilityHidden(true)
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week) { day in
                        DayCell(day: day) { onDayTap(day.date) }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            HStack(spacing: Spacing.x16) {
                LegendItem(color: .accentPrimary, label: "calendar_legend_completed")
                LegendItem(color: .dataBlue, label: "calendar_legend_scheduled")
            }
            .padding(.top, Spacing.x8)
        }
        .padding(.horizontal, Spacing.x4)
        .padding(.vertical, Spacing.x12)
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
    }
}

private struct DayCell: View {
    let day: CalendarDayUi
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text("\(day.date.day)")
                    .textStyle(day.isSelected || day.isToday ? .headline : .callout)
                    .foregroundStyle(textColor)
                    .frame(width: 36, height: 36)
                    .background(day.isSelected ? Color.accentPrimary : .clear, in: .circle)
                    .overlay(Circle().inset(by: 0.75).stroke(day.isToday && !day.isSelected ? Color.accentPrimary : .clear, lineWidth: 1.5))
                Circle().fill(markColor).frame(width: 5, height: 5)
            }
            .frame(width: 44, height: 48)
            .contentShape(.rect(cornerRadius: Radius.sm))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text(day.date.middayDate.formatted(date: .complete, time: .omitted)))
        .accessibilityAddTraits(day.isSelected ? .isSelected : [])
    }

    private var textColor: Color {
        if day.isSelected { return .accentOn }
        if day.isToday { return .accentPrimary }
        return day.inMonth ? .textPrimary : .textTertiary
    }

    private var markColor: Color {
        switch day.mark {
        case .completed: .accentPrimary
        case .scheduled: .dataBlue
        case .none: .clear
        }
    }
}

private struct NavButton: View {
    let icon: String
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundStyle(Color.textPrimary)
                .frame(width: 32, height: 32)
                .contentShape(.circle)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text(label))
    }
}

private struct LegendItem: View {
    let color: Color
    let label: LocalizedStringKey

    var body: some View {
        HStack(spacing: Spacing.x4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).textStyle(.caption).foregroundStyle(Color.textSecondary)
        }
    }
}

#Preview {
    let today = Day(year: 2026, month: 9, day: 29)
    let start = Day(year: 2026, month: 8, day: 31)
    let weeks = (0..<5).map { week in
        (0..<7).map { offset in
            let date = start.adding(days: week * 7 + offset)
            return CalendarDayUi(
                date: date, inMonth: date.month == 9, isToday: date == today, isSelected: date == today.adding(days: 1),
                mark: date < today && date.day % 2 == 1 ? .completed : (date == today.adding(days: 1) ? .scheduled : .none)
            )
        }
    }
    MonthCalendar(
        title: "September 2026", weekdayLabels: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], weeks: weeks,
        onPreviousTap: {}, onNextTap: {}, onDayTap: { _ in }
    )
    .padding()
    .background(Color.bgBase)
}

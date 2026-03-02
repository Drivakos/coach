//
//  WeekStrip.swift
//  coach
//

import SwiftUI

struct WeekStrip: View {
    @Binding var selectedDate: Date

    private let calendar = Calendar.current

    private var weekDays: [Date] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday - 2 + 7) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { day in
                DayCell(
                    date: day,
                    isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
                    isToday: calendar.isDateInToday(day)
                )
                .frame(maxWidth: .infinity)
                .onTapGesture { selectedDate = day }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
    }
}

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool

    private var abbrev: String { date.formatted(.dateTime.weekday(.abbreviated)) }
    private var number: String { date.formatted(.dateTime.day()) }

    var body: some View {
        VStack(spacing: 5) {
            Text(abbrev)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(number)
                .font(.callout)
                .fontWeight(isSelected || isToday ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : (isToday ? .accentColor : .primary))
                .frame(width: 30, height: 30)
                .background(isSelected ? Color.accentColor : .clear, in: Circle())
        }
    }
}

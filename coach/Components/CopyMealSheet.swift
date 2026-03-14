import SwiftUI

struct CopyMealSheet: View {
    let title: String
    let currentDate: Date
    let onCopy: ([Date]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDates: Set<Date> = []
    @State private var displayedMonth: Date

    private static let cal = Calendar.current
    private let today = Calendar.current.startOfDay(for: Date())
    private let sourceDay: Date

    init(title: String, currentDate: Date, onCopy: @escaping ([Date]) -> Void) {
        self.title = title
        self.currentDate = currentDate
        self.onCopy = onCopy
        self.sourceDay = Calendar.current.startOfDay(for: currentDate)
        // Start on the month containing currentDate
        let comps = Calendar.current.dateComponents([.year, .month], from: currentDate)
        self._displayedMonth = State(initialValue: Calendar.current.date(from: comps)!)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                calendarHeader
                Divider()
                weekdayLabels
                calendarGrid
                Spacer()
                if !selectedDates.isEmpty {
                    selectedSummary
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selectedDates.count > 1 ? "Copy (\(selectedDates.count))" : "Copy") {
                        onCopy(Array(selectedDates))
                        dismiss()
                    }
                    .disabled(selectedDates.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Calendar header (month + nav arrows)

    private var calendarHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            Spacer()
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
            Spacer()
            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    // MARK: - Weekday labels (Mon Tue … Sun)

    private var weekdayLabels: some View {
        HStack(spacing: 0) {
            ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: - Calendar grid

    private var calendarGrid: some View {
        let days = daysInMonth()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
            ForEach(days, id: \.self) { date in
                if let date {
                    dayCell(date)
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        let isSource   = date == sourceDay
        let isToday    = date == today
        let isSelected = selectedDates.contains(date)

        Button {
            guard !isSource else { return }
            if isSelected {
                selectedDates.remove(date)
            } else {
                selectedDates.insert(date)
            }
        } label: {
            ZStack {
                // Selected fill
                if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                }
                // Today ring (shown when not selected)
                if isToday && !isSelected {
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                }
                // Source day dim background
                if isSource {
                    Circle()
                        .fill(Color(.systemFill))
                }
                Text("\(Self.cal.component(.day, from: date))")
                    .font(.body.weight(isToday ? .semibold : .regular))
                    .foregroundStyle(
                        isSource   ? Color.secondary :
                        isSelected ? Color.white      :
                        isToday    ? Color.accentColor : Color.primary
                    )
            }
            .frame(height: 44)
        }
        .disabled(isSource)
    }

    // MARK: - Selected summary strip

    private var selectedSummary: some View {
        let sorted = selectedDates.sorted()
        let label: String
        if sorted.count == 1 {
            label = sorted[0].formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        } else {
            label = "\(sorted.count) days selected"
        }
        return Text(label)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.bottom, 12)
    }

    // MARK: - Helpers

    private var orderedWeekdaySymbols: [String] {
        let syms = Self.cal.shortWeekdaySymbols // Sun Mon … Sat
        let first = Self.cal.firstWeekday - 1   // 0-indexed
        return Array(syms[first...] + syms[..<first])
    }

    private func daysInMonth() -> [Date?] {
        guard
            let monthStart   = Self.cal.date(from: Self.cal.dateComponents([.year, .month], from: displayedMonth)),
            let range        = Self.cal.range(of: .day, in: .month, for: monthStart),
            let firstWeekday = Self.cal.dateComponents([.weekday], from: monthStart).weekday
        else { return [] }

        // Offset so the grid aligns with the locale's first weekday
        let firstWeekdayIndex = ((firstWeekday - Self.cal.firstWeekday) + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: firstWeekdayIndex)

        for day in range {
            if let date = Self.cal.date(byAdding: .day, value: day - 1, to: monthStart) {
                cells.append(Self.cal.startOfDay(for: date))
            }
        }
        return cells
    }

    private func shiftMonth(by value: Int) {
        if let shifted = Self.cal.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = shifted
        }
    }
}

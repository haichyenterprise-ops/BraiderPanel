import SwiftUI

struct ServiceAvailabilityEditor: View {
    let serviceName: String
    @Binding var availableDates: [Date]
    @Binding var availableSlots: [String: [String]]

    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate = Date()
    @State private var appeared = false

    private let allTimes = [
        "9:00 AM", "10:00 AM", "10:30 AM", "11:00 AM", "12:00 PM",
        "1:00 PM", "1:30 PM", "2:00 PM", "3:00 PM", "4:00 PM",
        "4:30 PM", "5:00 PM", "6:00 PM", "7:00 PM"
    ]

    private var dateKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: selectedDate)
    }

    private var slotsForSelectedDate: [String] {
        availableSlots[dateKey] ?? []
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.cloud.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        header
                        calendarCard
                        publishedDatesList
                        timePickerCard
                        Color.clear.frame(height: 40)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Availability")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(AppTheme.sans(15, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                }
            }
        }
        .onAppear {
            if let first = availableDates.sorted().first {
                selectedDate = first
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.05)) {
                appeared = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FOR THIS SERVICE")
                .font(AppTheme.sans(10, weight: .bold))
                .tracking(1.6)
                .foregroundColor(AppTheme.accentDeep)
            Text(serviceName)
                .font(AppTheme.serif(24))
                .foregroundColor(AppTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Calendar

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Pick a date")

            DatePicker(
                "",
                selection: $selectedDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(AppTheme.ink)

            if hasSlots(for: selectedDate) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.success)
                    Text("\(slotsForSelectedDate.count) time\(slotsForSelectedDate.count == 1 ? "" : "s") set")
                        .font(AppTheme.sans(12, weight: .medium))
                        .foregroundColor(AppTheme.success)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.stone)
                    Text("No times for this date")
                        .font(AppTheme.sans(12, weight: .medium))
                        .foregroundColor(AppTheme.stone)
                }
            }
        }
        .padding(16)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
    }

    // MARK: - Published dates

    private var publishedDatesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: "Published dates")
                Spacer()
                Text("\(availableDates.count)")
                    .font(AppTheme.sans(11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(AppTheme.accent, in: Circle())
            }

            if availableDates.isEmpty {
                Text("No dates yet. Add time slots below to publish a date.")
                    .font(AppTheme.sans(13))
                    .foregroundColor(AppTheme.stone)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(availableDates.sorted(), id: \.self) { date in
                            DatePill(
                                date: date,
                                slotCount: (availableSlots[dateKeyFor(date)] ?? []).count,
                                isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate)
                            ) {
                                Haptics.select()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    selectedDate = date
                                }
                            } onDelete: {
                                Haptics.warning()
                                withAnimation {
                                    availableSlots.removeValue(forKey: dateKeyFor(date))
                                    availableDates.removeAll { Calendar.current.isDate($0, inSameDayAs: date) }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Time picker

    private var timePickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: "Times for \(selectedDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))")
                Spacer()
                if !slotsForSelectedDate.isEmpty {
                    Button {
                        Haptics.warning()
                        withAnimation {
                            availableSlots.removeValue(forKey: dateKey)
                            availableDates.removeAll { Calendar.current.isDate($0, inSameDayAs: selectedDate) }
                        }
                    } label: {
                        Text("Clear")
                            .font(AppTheme.sans(12, weight: .semibold))
                            .foregroundColor(AppTheme.danger)
                    }
                }
            }

            FlowLayout(spacing: 8) {
                ForEach(allTimes, id: \.self) { time in
                    let isOn = slotsForSelectedDate.contains(time)
                    Button {
                        Haptics.select()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                            var current = availableSlots[dateKey] ?? []
                            if isOn {
                                current.removeAll { $0 == time }
                            } else {
                                current.append(time)
                                current.sort { parseTime($0) < parseTime($1) }
                            }
                            if current.isEmpty {
                                availableSlots.removeValue(forKey: dateKey)
                                availableDates.removeAll { Calendar.current.isDate($0, inSameDayAs: selectedDate) }
                            } else {
                                availableSlots[dateKey] = current
                                if !availableDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: selectedDate) }) {
                                    availableDates.append(selectedDate)
                                    availableDates.sort()
                                }
                            }
                        }
                    } label: {
                        Text(time)
                            .font(AppTheme.sans(13, weight: .semibold))
                            .foregroundColor(isOn ? .white : AppTheme.ink)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(isOn ? AppTheme.ink : AppTheme.snow, in: Capsule())
                            .overlay(
                                Capsule().stroke(
                                    isOn ? Color.clear : AppTheme.hairline,
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(SoftPress())
                }
            }
        }
        .padding(16)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func hasSlots(for date: Date) -> Bool {
        !(availableSlots[dateKeyFor(date)] ?? []).isEmpty
    }

    private func dateKeyFor(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func parseTime(_ label: String) -> Int {
        let upper = label.uppercased()
        guard let hourPart = upper.split(separator: ":").first,
              var hour = Int(hourPart) else { return 0 }
        if upper.contains("PM") && hour != 12 { hour += 12 }
        if upper.contains("AM") && hour == 12 { hour = 0 }
        let minutePart = upper.split(separator: ":").dropFirst().first ?? "0"
        let minute = Int(minutePart.prefix(2)) ?? 0
        return hour * 60 + minute
    }
}
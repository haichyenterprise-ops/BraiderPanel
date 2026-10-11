import SwiftUI

struct EditAvailabilitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared

    @State private var selectedDate = Date()
    @State private var slots: [String: [String]] = [:]
    @State private var availableDates: [Date] = []
    @State private var saving = false
    @State private var errorMessage: String?

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
        slots[dateKey] ?? []
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.cloud.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        calendarCard
                        datesList
                        timePickerCard
                        Color.clear.frame(height: 120)
                    }
                    .padding(20)
                }

                VStack {
                    Spacer()
                    footer
                }
            }
            .navigationTitle("Availability")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(AppTheme.sans(15, weight: .medium))
                        .foregroundColor(AppTheme.slate)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .onAppear {
            if let b = fb.myBraider {
                slots = b.availableSlots
                availableDates = b.availableDates.sorted()
                if let first = availableDates.first {
                    selectedDate = first
                }
            }
        }
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

    // MARK: - Dates list

    private var datesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: "Your published dates")
                Spacer()
                Text("\(availableDates.count)")
                    .font(AppTheme.sans(11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(AppTheme.accent, in: Circle())
            }

            if availableDates.isEmpty {
                VStack(spacing: 8) {
                    Text("No dates published")
                        .font(AppTheme.sans(14, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                    Text("Add time slots to a date below to publish it.")
                        .font(AppTheme.sans(12))
                        .foregroundColor(AppTheme.slate)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(AppTheme.mist.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(availableDates, id: \.self) { date in
                            DatePill(
                                date: date,
                                slotCount: (slots[dateKeyFor(date)] ?? []).count,
                                isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate)
                            ) {
                                Haptics.select()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    selectedDate = date
                                }
                            } onDelete: {
                                Haptics.warning()
                                withAnimation {
                                    slots.removeValue(forKey: dateKeyFor(date))
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
                            slots.removeValue(forKey: dateKey)
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
                            var current = slots[dateKey] ?? []
                            if isOn {
                                current.removeAll { $0 == time }
                            } else {
                                current.append(time)
                                current.sort { parseTime($0) < parseTime($1) }
                            }
                            if current.isEmpty {
                                slots.removeValue(forKey: dateKey)
                                availableDates.removeAll { Calendar.current.isDate($0, inSameDayAs: selectedDate) }
                            } else {
                                slots[dateKey] = current
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
                            .shadow(
                                color: isOn ? AppTheme.ink.opacity(0.15) : .clear,
                                radius: 8, y: 3
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

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [AppTheme.cloud.opacity(0), AppTheme.cloud, AppTheme.cloud],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 30)

            PrimaryButton(
                title: saving ? "Saving…" : "Save availability",
                icon: "checkmark",
                loading: saving
            ) {
                save()
            }
            .disabled(saving)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .background(AppTheme.cloud)
        }
    }

    // MARK: - Helpers

    private func hasSlots(for date: Date) -> Bool {
        !(slots[dateKeyFor(date)] ?? []).isEmpty
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

    private func save() {
        let uid = session.uid
        guard !uid.isEmpty else { return }
        saving = true
        Haptics.medium()

        let dateTimestamps = availableDates.sorted()

        Task {
            do {
                try await FirebaseManager.shared.updateBraider(uid: uid, data: [
                    "availableSlots": slots,
                    "availableDates": dateTimestamps
                ])
                await MainActor.run {
                    saving = false
                    Haptics.success()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    saving = false
                    errorMessage = error.localizedDescription
                    Haptics.error()
                }
            }
        }
    }
}

// MARK: - Date pill

struct DatePill: View {
    let date: Date
    let slotCount: Int
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(AppTheme.sans(10, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(isSelected ? .white.opacity(0.75) : AppTheme.stone)

                Text(date.formatted(.dateTime.day()))
                    .font(AppTheme.serif(22))
                    .foregroundColor(isSelected ? .white : AppTheme.ink)

                Text("\(slotCount)")
                    .font(AppTheme.sans(10, weight: .bold))
                    .foregroundColor(isSelected ? .white.opacity(0.75) : AppTheme.accent)
            }
            .frame(width: 62, height: 88)
            .background(isSelected ? AppTheme.ink : AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? Color.clear : AppTheme.hairline,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isSelected ? AppTheme.ink.opacity(0.2) : .black.opacity(0.03),
                radius: isSelected ? 10 : 3,
                y: isSelected ? 5 : 1
            )
        }
        .buttonStyle(SoftPress())
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Remove date", systemImage: "trash")
            }
        }
    }
}
import SwiftUI

struct BookingsView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared

    @State private var bookings: [Booking] = []
    @State private var filter: Filter = .upcoming
    @State private var loading = false
    @State private var appeared = false

    enum Filter: String, CaseIterable {
        case upcoming = "Upcoming"
        case past = "Past"
    }

    private var filtered: [Booking] {
        let now = Date()
        return bookings
            .filter { booking in
                if filter == .upcoming {
                    return booking.date >= Calendar.current.startOfDay(for: now)
                } else {
                    return booking.date < Calendar.current.startOfDay(for: now)
                }
            }
            .sorted { filter == .upcoming ? $0.date < $1.date : $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.cloud.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    filterTabs

                    if loading && bookings.isEmpty {
                        loadingState
                    } else if filtered.isEmpty {
                        emptyState
                    } else {
                        listView
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.1)) {
                    appeared = true
                }
                Task { await load() }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BOOKINGS")
                        .font(AppTheme.sans(11, weight: .bold))
                        .tracking(2.0)
                        .foregroundColor(AppTheme.accentDeep)

                    Text("Your calendar")
                        .font(AppTheme.serif(28))
                        .foregroundColor(AppTheme.ink)
                }

                Spacer()

                Button {
                    Haptics.soft()
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.snow, in: Circle())
                        .overlay(Circle().stroke(AppTheme.hairline, lineWidth: 0.5))
                }
                .buttonStyle(BouncyPress())
            }

            Text(summary)
                .font(AppTheme.sans(13))
                .foregroundColor(AppTheme.slate)
                .padding(.top, 2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 60)
        .padding(.bottom, 20)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private var summary: String {
        let upcoming = bookings.filter { $0.date >= Calendar.current.startOfDay(for: Date()) }.count
        if upcoming == 0 {
            return "No upcoming bookings"
        }
        return "\(upcoming) upcoming · \(bookings.count) total"
    }

    // MARK: - Filter tabs

    private var filterTabs: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases, id: \.self) { f in
                Button {
                    Haptics.select()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        filter = f
                    }
                } label: {
                    Text(f.rawValue)
                        .font(AppTheme.sans(13, weight: .semibold))
                        .foregroundColor(filter == f ? .white : AppTheme.ink)
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background(filter == f ? AppTheme.ink : AppTheme.snow, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(filter == f ? Color.clear : AppTheme.hairline, lineWidth: 0.5)
                        )
                }
                .buttonStyle(SoftPress())
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().tint(AppTheme.accent)
            Text("Loading bookings…")
                .font(AppTheme.sans(13))
                .foregroundColor(AppTheme.slate)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle().fill(AppTheme.accentSoft).frame(width: 100, height: 100)
                Image(systemName: filter == .upcoming ? "calendar.badge.plus" : "clock.arrow.circlepath")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(AppTheme.accent)
            }
            .scaleEffect(appeared ? 1 : 0.85)

            VStack(spacing: 8) {
                Text(filter == .upcoming ? "No upcoming bookings" : "No past bookings")
                    .font(AppTheme.serif(22))
                    .foregroundColor(AppTheme.ink)
                Text(filter == .upcoming
                     ? "When customers book you through BraidMe, their appointments appear here."
                     : "Your completed appointments will show here.")
                    .font(AppTheme.sans(14))
                    .foregroundColor(AppTheme.slate)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

    // MARK: - List

    private var listView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, booking in
                    BookingCard(booking: booking)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(
                            .spring(response: 0.7, dampingFraction: 0.85)
                                .delay(Double(idx) * 0.05),
                            value: appeared
                        )
                }

                Color.clear.frame(height: 140)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .refreshable {
            await load()
        }
    }

    // MARK: - Load

    private func load() async {
        guard let braiderId = fb.myBraider?.id, !braiderId.isEmpty else {
            await MainActor.run { loading = false }
            return
        }
        await MainActor.run { loading = true }
        let fetched = await fb.fetchBookings(forBraiderId: braiderId)
        await MainActor.run {
            self.bookings = fetched
            self.loading = false
        }
    }
}

// MARK: - Booking Card

struct BookingCard: View {
    let booking: Booking

    @State private var expanded = false

    var body: some View {
        Button {
            Haptics.soft()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                expanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 14) {

                HStack(alignment: .top, spacing: 14) {
                    dateBadge
                    VStack(alignment: .leading, spacing: 4) {
                        Text(booking.style)
                            .font(AppTheme.serif(18))
                            .foregroundColor(AppTheme.ink)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.stone)
                            Text(booking.customerName)
                                .font(AppTheme.sans(13, weight: .medium))
                                .foregroundColor(AppTheme.slate)
                        }

                        Text("£\(booking.price)")
                            .font(AppTheme.sans(15, weight: .bold))
                            .foregroundColor(AppTheme.accentDeep)
                            .padding(.top, 2)
                    }

                    Spacer()

                    statusBadge
                }

                if expanded {
                    Divider().background(AppTheme.hairline)

                    VStack(alignment: .leading, spacing: 10) {
                        detailRow(icon: "clock.fill", label: "Time", value: booking.time)
                        detailRow(icon: "calendar", label: "Date",
                                  value: booking.date.formatted(date: .long, time: .omitted))
                        detailRow(icon: "number", label: "Booking ID",
                                  value: String(booking.id.prefix(8)))
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))

                    HStack(spacing: 10) {
                        Button {
                            Haptics.soft()
                            // Future: contact customer
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Contact")
                                    .font(AppTheme.sans(13, weight: .semibold))
                            }
                            .foregroundColor(AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(AppTheme.mist, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(SoftPress())

                        Button {
                            Haptics.success()
                            // Future: mark complete
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Complete")
                                    .font(AppTheme.sans(13, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(AppTheme.success, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(SoftPress())
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppTheme.hairline.opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        }
        .buttonStyle(CardPress())
    }

    private var dateBadge: some View {
        VStack(spacing: 0) {
            Text(booking.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                .font(AppTheme.sans(9, weight: .bold))
                .tracking(0.8)
                .foregroundColor(.white.opacity(0.75))
            Text(booking.date.formatted(.dateTime.day()))
                .font(AppTheme.serif(22))
                .foregroundColor(.white)
        }
        .frame(width: 54, height: 62)
        .background(monthColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var monthColor: Color {
        if booking.date < Calendar.current.startOfDay(for: Date()) {
            return AppTheme.stone
        }
        if Calendar.current.isDateInToday(booking.date) {
            return AppTheme.accent
        }
        return AppTheme.ink
    }

    private var statusBadge: some View {
        let (label, color): (String, Color) = {
            switch booking.status {
            case "confirmed": return ("Confirmed", AppTheme.success)
            case "completed": return ("Completed", AppTheme.slate)
            case "cancelled": return ("Cancelled", AppTheme.danger)
            default: return (booking.status.capitalized, AppTheme.stone)
            }
        }()

        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(AppTheme.sans(10, weight: .bold))
                .tracking(0.4)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.accent)
                .frame(width: 16)
            Text(label)
                .font(AppTheme.sans(12, weight: .medium))
                .foregroundColor(AppTheme.stone)
            Spacer()
            Text(value)
                .font(AppTheme.sans(13, weight: .semibold))
                .foregroundColor(AppTheme.ink)
        }
    }
}
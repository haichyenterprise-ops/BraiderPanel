import SwiftUI

struct BookingsView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared

    @State private var bookings: [Booking] = []
    @State private var filter: Filter = .upcoming
    @State private var loading = false
    @State private var appeared = false
    @State private var activeChat: Booking?
    @State private var approvingId: String?
    @State private var showConfirmApprove: Booking?

    enum Filter: String, CaseIterable {
        case upcoming = "Upcoming"
        case requests = "Requests"
        case past = "Past"
    }

    private var pendingRequests: [Booking] {
        bookings.filter { $0.status == "cancellation_requested" }
    }

    private var filtered: [Booking] {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)

        switch filter {
        case .upcoming:
            return bookings
                .filter { $0.status == "confirmed" && $0.date >= startOfToday }
                .sorted { $0.date < $1.date }
        case .requests:
            return pendingRequests.sorted {
                ($0.cancellationRequestedAt ?? .distantPast) > ($1.cancellationRequestedAt ?? .distantPast)
            }
        case .past:
            return bookings
                .filter { b in
                    b.date < startOfToday
                    || b.status == "completed"
                    || b.status == "cancelled"
                    || b.status == "cancellation_denied"
                }
                .sorted { $0.date > $1.date }
        }
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
            .sheet(item: $activeChat) { booking in
                BraiderChatView(
                    booking: booking,
                    braiderId: fb.myBraider?.id ?? ""
                )
            }
            .alert("Approve cancellation?", isPresented: Binding(
                get: { showConfirmApprove != nil },
                set: { if !$0 { showConfirmApprove = nil } }
            )) {
                Button("Approve", role: .destructive) {
                    if let booking = showConfirmApprove { approve(booking) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The customer's booking will be cancelled and they'll be notified.")
            }
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
        let upcoming = bookings.filter { $0.status == "confirmed" && $0.date >= Date() }.count
        let requests = pendingRequests.count
        if requests > 0 {
            return "\(requests) cancellation request\(requests == 1 ? "" : "s") · \(upcoming) upcoming"
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
                    HStack(spacing: 6) {
                        Text(f.rawValue)
                            .font(AppTheme.sans(13, weight: .semibold))
                        if f == .requests && !pendingRequests.isEmpty {
                            Text("\(pendingRequests.count)")
                                .font(AppTheme.sans(10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 18, minHeight: 18)
                                .padding(.horizontal, 4)
                                .background(AppTheme.danger, in: Capsule())
                        }
                    }
                    .foregroundColor(filter == f ? .white : AppTheme.ink)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(filter == f ? AppTheme.ink : AppTheme.snow, in: Capsule())
                    .overlay(
                        Capsule().stroke(filter == f ? Color.clear : AppTheme.hairline, lineWidth: 0.5)
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
                Image(systemName: emptyIcon)
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(AppTheme.accent)
            }
            .scaleEffect(appeared ? 1 : 0.85)

            VStack(spacing: 8) {
                Text(emptyTitle)
                    .font(AppTheme.serif(22))
                    .foregroundColor(AppTheme.ink)
                Text(emptySubtitle)
                    .font(AppTheme.sans(14))
                    .foregroundColor(AppTheme.slate)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

    private var emptyIcon: String {
        switch filter {
        case .upcoming: return "calendar.badge.plus"
        case .requests: return "checkmark.circle"
        case .past: return "clock.arrow.circlepath"
        }
    }

    private var emptyTitle: String {
        switch filter {
        case .upcoming: return "No upcoming bookings"
        case .requests: return "No pending requests"
        case .past: return "No past bookings"
        }
    }

    private var emptySubtitle: String {
        switch filter {
        case .upcoming: return "New bookings from the BraidMe app will appear here."
        case .requests: return "You're all caught up. No cancellation requests to review."
        case .past: return "Your completed appointments will show here."
        }
    }

    // MARK: - List

    private var listView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, booking in
                    Group {
                        if filter == .requests {
                            CancellationRequestCard(
                                booking: booking,
                                isApproving: approvingId == booking.id,
                                onApprove: { showConfirmApprove = booking },
                                onDeny: { deny(booking) },
                                onMessage: { activeChat = booking }
                            )
                        } else {
                            BraiderBookingCard(
                                booking: booking,
                                onMessage: { activeChat = booking }
                            )
                        }
                    }
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

    // MARK: - Actions

    private func approve(_ booking: Booking) {
        approvingId = booking.id
        Haptics.success()
        Task {
            try? await fb.approveCancellation(bookingId: booking.id)
            await load()
            await MainActor.run { approvingId = nil }
        }
    }

    private func deny(_ booking: Booking) {
        approvingId = booking.id
        Haptics.warning()
        Task {
            try? await fb.denyCancellation(bookingId: booking.id)
            await load()
            await MainActor.run { approvingId = nil }
        }
    }

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

// MARK: - Cancellation request card

struct CancellationRequestCard: View {
    let booking: Booking
    let isApproving: Bool
    let onApprove: () -> Void
    let onDeny: () -> Void
    let onMessage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(AppTheme.warn.opacity(0.15)).frame(width: 42, height: 42)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.warn)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Cancellation request")
                        .font(AppTheme.sans(15, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                    Text(booking.customerName)
                        .font(AppTheme.sans(12))
                        .foregroundColor(AppTheme.stone)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(booking.style)
                    .font(AppTheme.serif(17))
                    .foregroundColor(AppTheme.ink)
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.stone)
                    Text(booking.date.formatted(date: .abbreviated, time: .omitted))
                        .font(AppTheme.sans(13))
                        .foregroundColor(AppTheme.slate)
                    Text("·")
                        .foregroundColor(AppTheme.stone)
                    Text(booking.time)
                        .font(AppTheme.sans(13))
                        .foregroundColor(AppTheme.slate)
                    Spacer()
                    Text("£\(booking.price)")
                        .font(AppTheme.sans(13, weight: .bold))
                        .foregroundColor(AppTheme.accentDeep)
                }
            }

            if let reason = booking.cancellationReason, !reason.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CUSTOMER'S REASON")
                        .font(AppTheme.sans(9, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(AppTheme.stone)
                    Text(reason)
                        .font(AppTheme.sans(13))
                        .foregroundColor(AppTheme.ink)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(AppTheme.mist)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 10) {
                Button(action: onDeny) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                        Text("Deny")
                            .font(AppTheme.sans(13, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.danger)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(AppTheme.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.danger.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(SoftPress())

                Button(action: onApprove) {
                    ZStack {
                        if isApproving {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Approve")
                                    .font(AppTheme.sans(13, weight: .semibold))
                            }
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(AppTheme.success, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(SoftPress())
                .disabled(isApproving)
            }
        }
        .padding(16)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.warn.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}

// MARK: - Regular booking card

struct BraiderBookingCard: View {
    let booking: Booking
    let onMessage: () -> Void

    var body: some View {
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
                    HStack(spacing: 8) {
                        Text("£\(booking.price)")
                            .font(AppTheme.sans(15, weight: .bold))
                            .foregroundColor(AppTheme.accentDeep)
                        Text("·")
                            .foregroundColor(AppTheme.stone)
                        Text(booking.time)
                            .font(AppTheme.sans(13))
                            .foregroundColor(AppTheme.slate)
                    }
                    .padding(.top, 2)
                }
                Spacer()
                statusBadge
            }

            if booking.status == "confirmed" {
                Button(action: onMessage) {
                    HStack(spacing: 6) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Message customer")
                            .font(AppTheme.sans(13, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(AppTheme.mist, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(SoftPress())
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
        if booking.date < Calendar.current.startOfDay(for: Date()) { return AppTheme.stone }
        if Calendar.current.isDateInToday(booking.date) { return AppTheme.accent }
        return AppTheme.ink
    }

    private var statusBadge: some View {
        let (label, color): (String, Color) = {
            switch booking.status {
            case "confirmed": return ("Confirmed", AppTheme.success)
            case "completed": return ("Completed", AppTheme.slate)
            case "cancelled": return ("Cancelled", AppTheme.danger)
            case "cancellation_requested": return ("Pending", AppTheme.warn)
            case "cancellation_denied": return ("Denied", AppTheme.rose)
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
}
import SwiftUI

struct EarningsView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared

    @State private var bookings: [Booking] = []
    @State private var loading = false
    @State private var appeared = false
    @State private var selectedRange: Range = .week

    enum Range: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case all = "All"
    }

    // MARK: - Computed stats

    private var totalEarnings: Int {
        bookings.filter { $0.status != "cancelled" }.reduce(0) { $0 + $1.price }
    }

    private var thisMonthEarnings: Int {
        let start = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
        return bookings
            .filter { $0.date >= start && $0.status != "cancelled" }
            .reduce(0) { $0 + $1.price }
    }

    private var thisWeekEarnings: Int {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return bookings
            .filter { $0.date >= start && $0.status != "cancelled" }
            .reduce(0) { $0 + $1.price }
    }

    private var completedCount: Int {
        bookings.filter { $0.status == "completed" }.count
    }

    private var upcomingCount: Int {
        let start = Calendar.current.startOfDay(for: Date())
        return bookings.filter { $0.date >= start && $0.status == "confirmed" }.count
    }

    private var avgBookingValue: Int {
        let valid = bookings.filter { $0.status != "cancelled" }
        guard !valid.isEmpty else { return 0 }
        return totalEarnings / valid.count
    }

    // MARK: - Chart data

    private var last7Days: [(label: String, value: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"

        return (0..<7).reversed().map { offset -> (String, Int) in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else {
                return ("—", 0)
            }
            let nextDay = cal.date(byAdding: .day, value: 1, to: day) ?? day
            let total = bookings
                .filter { $0.date >= day && $0.date < nextDay && $0.status != "cancelled" }
                .reduce(0) { $0 + $1.price }
            return (formatter.string(from: day), total)
        }
    }

    private var chartMax: Int {
        max(last7Days.map { $0.value }.max() ?? 0, 1)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.cloud.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        header
                        bigNumberCard
                        quickStatsRow
                        chartCard
                        rangeTabs
                        breakdownCard
                        Color.clear.frame(height: 140)
                    }
                    .padding(.horizontal, 24)
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
            Text("EARNINGS")
                .font(AppTheme.sans(11, weight: .bold))
                .tracking(2.0)
                .foregroundColor(AppTheme.accentDeep)

            Text("Your business")
                .font(AppTheme.serif(28))
                .foregroundColor(AppTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 60)
        .padding(.bottom, 4)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Big number

    private var bigNumberCard: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [Color(hex: "#1C222C"), Color(hex: "#0A0D12")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            // Decorative circle
            Circle()
                .fill(AppTheme.accent.opacity(0.25))
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .offset(x: 80, y: -60)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppTheme.accentLight)
                        Text("TOTAL EARNED")
                            .font(AppTheme.sans(10, weight: .bold))
                            .tracking(1.6)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.accentLight.opacity(0.7))
                }

                Text("£\(totalEarnings)")
                    .font(.system(size: 48, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: totalEarnings)

                HStack(spacing: 16) {
                    miniStat(label: "This week", value: "£\(thisWeekEarnings)")
                    miniStat(label: "This month", value: "£\(thisMonthEarnings)")
                }
            }
            .padding(22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private func miniStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(AppTheme.sans(9, weight: .bold))
                .tracking(1.0)
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(AppTheme.sans(15, weight: .bold))
                .foregroundColor(.white)
        }
    }

    // MARK: - Quick stats

    private var quickStatsRow: some View {
        HStack(spacing: 12) {
            quickStatCard(icon: "checkmark.circle.fill", value: "\(completedCount)", label: "Completed", tint: AppTheme.success)
            quickStatCard(icon: "clock.fill", value: "\(upcomingCount)", label: "Upcoming", tint: AppTheme.accent)
            quickStatCard(icon: "sterlingsign.circle.fill", value: "£\(avgBookingValue)", label: "Avg value", tint: AppTheme.gold)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private func quickStatCard(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(tint.opacity(0.15)).frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(tint)
            }
            Text(value)
                .font(AppTheme.serif(20))
                .foregroundColor(AppTheme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label.uppercased())
                .font(AppTheme.sans(9, weight: .bold))
                .tracking(0.8)
                .foregroundColor(AppTheme.stone)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.hairline.opacity(0.55), lineWidth: 0.5)
        )
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("LAST 7 DAYS")
                    .font(AppTheme.sans(10, weight: .bold))
                    .tracking(1.4)
                    .foregroundColor(AppTheme.stone)
                Spacer()
                Text("£\(last7Days.reduce(0) { $0 + $1.value })")
                    .font(AppTheme.sans(13, weight: .bold))
                    .foregroundColor(AppTheme.ink)
            }

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(last7Days.enumerated()), id: \.offset) { idx, day in
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppTheme.mist)
                                .frame(height: 100)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.accentLight, AppTheme.accent],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .frame(height: barHeight(value: day.value))
                                .animation(
                                    .spring(response: 0.9, dampingFraction: 0.8)
                                        .delay(Double(idx) * 0.05),
                                    value: appeared
                                )
                        }
                        .frame(height: 100)

                        Text(day.label)
                            .font(AppTheme.sans(10, weight: .semibold))
                            .foregroundColor(AppTheme.stone)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.hairline.opacity(0.55), lineWidth: 0.5)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private func barHeight(value: Int) -> CGFloat {
        guard chartMax > 0 else { return 0 }
        let ratio = CGFloat(value) / CGFloat(chartMax)
        return max(6, ratio * 100)
    }

    // MARK: - Range tabs

    private var rangeTabs: some View {
        HStack(spacing: 8) {
            ForEach(Range.allCases, id: \.self) { r in
                Button {
                    Haptics.select()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedRange = r
                    }
                } label: {
                    Text(r.rawValue)
                        .font(AppTheme.sans(13, weight: .semibold))
                        .foregroundColor(selectedRange == r ? .white : AppTheme.ink)
                        .padding(.horizontal, 16)
                        .frame(height: 34)
                        .background(selectedRange == r ? AppTheme.ink : AppTheme.snow, in: Capsule())
                        .overlay(
                            Capsule().stroke(
                                selectedRange == r ? Color.clear : AppTheme.hairline,
                                lineWidth: 0.5
                            )
                        )
                }
                .buttonStyle(SoftPress())
            }
            Spacer()
        }
    }

    // MARK: - Breakdown

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SERVICE BREAKDOWN")
                .font(AppTheme.sans(10, weight: .bold))
                .tracking(1.4)
                .foregroundColor(AppTheme.stone)

            if serviceBreakdown.isEmpty {
                Text("No services booked yet.")
                    .font(AppTheme.sans(13))
                    .foregroundColor(AppTheme.stone)
                    .italic()
                    .padding(.vertical, 8)
            } else {
                ForEach(serviceBreakdown, id: \.name) { item in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(AppTheme.sans(14, weight: .semibold))
                                .foregroundColor(AppTheme.ink)
                            Text("\(item.count) bookings")
                                .font(AppTheme.sans(11))
                                .foregroundColor(AppTheme.stone)
                        }

                        Spacer()

                        Text("£\(item.total)")
                            .font(AppTheme.sans(15, weight: .bold))
                            .foregroundColor(AppTheme.accentDeep)
                    }
                    .padding(.vertical, 4)

                    if item.name != serviceBreakdown.last?.name {
                        Divider().background(AppTheme.hairline)
                    }
                }
            }
        }
        .padding(18)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.hairline.opacity(0.55), lineWidth: 0.5)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private var serviceBreakdown: [(name: String, count: Int, total: Int)] {
        var map: [String: (Int, Int)] = [:]
        for b in bookings where b.status != "cancelled" {
            let current = map[b.style] ?? (0, 0)
            map[b.style] = (current.0 + 1, current.1 + b.price)
        }
        return map
            .map { (name: $0.key, count: $0.value.0, total: $0.value.1) }
            .sorted { $0.total > $1.total }
    }

    // MARK: - Load

    private func load() async {
        guard let braiderId = fb.myBraider?.id, !braiderId.isEmpty else { return }
        await MainActor.run { loading = true }
        let fetched = await fb.fetchBookings(forBraiderId: braiderId)
        await MainActor.run {
            self.bookings = fetched
            self.loading = false
        }
    }
}
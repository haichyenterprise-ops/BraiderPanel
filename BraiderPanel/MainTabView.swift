import SwiftUI

struct MainTabView: View {
    @StateObject private var fb = FirebaseManager.shared
    @EnvironmentObject private var session: SessionManager

    @State private var selectedTab: Tab = .profile
    @State private var showSettings = false

    enum Tab: String, CaseIterable {
        case profile = "Profile"
        case bookings = "Bookings"
        case earnings = "Earnings"

        var icon: String {
            switch self {
            case .profile: return "person.crop.circle.fill"
            case .bookings: return "calendar"
            case .earnings: return "chart.line.uptrend.xyaxis"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            // Content
            Group {
                switch selectedTab {
                case .profile:
                    BraiderProfileView()
                case .bookings:
                    BookingsView()
                case .earnings:
                    EarningsView()
                }
            }
            .transition(.opacity)

            // Custom tab bar
            tabBar
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 24, y: 10)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private func tabButton(_ tab: Tab) -> some View {
        let active = selectedTab == tab
        return Button {
            Haptics.select()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .semibold))
                if active {
                    Text(tab.rawValue)
                        .font(AppTheme.sans(13, weight: .semibold))
                }
            }
            .foregroundColor(active ? .white : AppTheme.ink)
            .padding(.horizontal, active ? 16 : 12)
            .frame(height: 44)
            .background(
                active
                    ? AnyView(AppTheme.inkGradient)
                    : AnyView(Color.clear)
            )
            .clipShape(Capsule())
            .overlay(alignment: .topTrailing) {
                if tab == .bookings && newBookingCount > 0 && !active {
                    Circle()
                        .fill(AppTheme.rose)
                        .frame(width: 8, height: 8)
                        .offset(x: -4, y: 4)
                }
            }
        }
        .buttonStyle(SoftPress())
    }

    private var newBookingCount: Int {
        fb.myBraider?.reviewCount ?? 0
    }
}
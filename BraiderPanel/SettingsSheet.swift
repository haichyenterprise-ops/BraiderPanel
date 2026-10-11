import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared

    @State private var showSignOutConfirm = false
    @State private var showShareSheet = false
    @State private var appeared = false

    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("autoAcceptBookings") private var autoAcceptBookings = false

    private var email: String {
        session.email ?? "Unknown"
    }

    private var name: String {
        fb.myBraider?.name ?? session.displayName ?? "Braider"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.cloud.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        profileCard
                        businessSection
                        preferencesSection
                        legalSection
                        signOutButton
                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(AppTheme.sans(15, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                }
            }
            .alert("Sign out?", isPresented: $showSignOutConfirm) {
                Button("Sign out", role: .destructive) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        session.signOut()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to log in again to manage your profile.")
            }
            .sheet(isPresented: $showShareSheet) {
                ShareProfileSheet()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.05)) {
                appeared = true
            }
        }
    }

    // MARK: - Profile card

    private var profileCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.inkGradient)
                    .frame(width: 58, height: 58)
                Text(initials)
                    .font(AppTheme.serif(22))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(AppTheme.sans(16, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                Text(email)
                    .font(AppTheme.sans(12))
                    .foregroundColor(AppTheme.stone)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()
        }
        .padding(16)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.hairline.opacity(0.55), lineWidth: 0.5)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    // MARK: - Business

    private var businessSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Business")

            VStack(spacing: 0) {
                settingRow(
                    icon: "square.and.arrow.up",
                    title: "Share your profile",
                    subtitle: "Send customers your BraidMe link",
                    trailing: "chevron",
                    action: { showShareSheet = true }
                )

                divider

                settingRow(
                    icon: "eye.fill",
                    title: "Preview as customer",
                    subtitle: "See how your profile appears",
                    trailing: "chevron",
                    action: {
                        dismiss()
                    }
                )

                divider

                settingRow(
                    icon: "doc.text.fill",
                    title: "Your info",
                    subtitle: "Name, addresses, phone",
                    trailing: "chevron",
                    action: {}
                )
            }
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.hairline.opacity(0.55), lineWidth: 0.5)
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Preferences")

            VStack(spacing: 0) {
                toggleRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    subtitle: "Alerts for new bookings",
                    isOn: $notificationsEnabled
                )

                divider

                toggleRow(
                    icon: "checkmark.circle.fill",
                    title: "Auto-accept bookings",
                    subtitle: "Skip manual confirmation",
                    isOn: $autoAcceptBookings
                )
            }
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.hairline.opacity(0.55), lineWidth: 0.5)
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "About")

            VStack(spacing: 0) {
                settingRow(
                    icon: "shield.fill",
                    title: "Privacy Policy",
                    subtitle: nil,
                    trailing: "chevron",
                    action: {}
                )

                divider

                settingRow(
                    icon: "doc.text",
                    title: "Terms of Service",
                    subtitle: nil,
                    trailing: "chevron",
                    action: {}
                )

                divider

                HStack {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(AppTheme.mist).frame(width: 32, height: 32)
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.slate)
                        }
                        Text("Version")
                            .font(AppTheme.sans(15, weight: .medium))
                            .foregroundColor(AppTheme.ink)
                    }
                    Spacer()
                    Text("1.0.0")
                        .font(AppTheme.mono(13))
                        .foregroundColor(AppTheme.stone)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.hairline.opacity(0.55), lineWidth: 0.5)
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Sign out

    private var signOutButton: some View {
        Button {
            Haptics.warning()
            showSignOutConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                Text("Sign Out")
                    .font(AppTheme.sans(15, weight: .semibold))
            }
            .foregroundColor(AppTheme.danger)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(AppTheme.snow)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.danger.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(SoftPress())
        .padding(.top, 4)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Helpers

    private var divider: some View {
        Divider().background(AppTheme.hairline).padding(.leading, 60)
    }

    private func settingRow(
        icon: String,
        title: String,
        subtitle: String?,
        trailing: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.soft()
            action()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(AppTheme.accentSoft).frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.sans(15, weight: .medium))
                        .foregroundColor(AppTheme.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(AppTheme.sans(11))
                            .foregroundColor(AppTheme.stone)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.ash)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(CardPress())
    }

    private func toggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(AppTheme.accentSoft).frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.sans(15, weight: .medium))
                    .foregroundColor(AppTheme.ink)
                Text(subtitle)
                    .font(AppTheme.sans(11))
                    .foregroundColor(AppTheme.stone)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(AppTheme.ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var session: SessionManager

    @State private var mode: AuthMode = .landing
    @State private var errorMessage: String?
    @State private var appeared = false

    enum AuthMode: Equatable {
        case landing
        case signup
        case login
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AppTheme.cloud.ignoresSafeArea()
                ambient

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: 40)

                        if mode == .landing {
                            landingView
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        } else {
                            EmailAuthView(
                                mode: mode == .signup ? .signup : .login,
                                onBack: {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                        mode = .landing
                                    }
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                        }

                        Spacer().frame(height: 40)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear { startEntrance() }
        .alert("Sign-In Failed", isPresented: bindingError) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var bindingError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    // MARK: - Ambient

    private var ambient: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [AppTheme.accent.opacity(0.20), .clear],
                    center: .center, startRadius: 0, endRadius: 220
                ))
                .frame(width: 460, height: 460)
                .blur(radius: 50)
                .offset(x: -140, y: -240)
                .opacity(appeared ? 1 : 0)

            Circle()
                .fill(RadialGradient(
                    colors: [AppTheme.plum.opacity(0.14), .clear],
                    center: .center, startRadius: 0, endRadius: 200
                ))
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .offset(x: 160, y: 300)
                .opacity(appeared ? 1 : 0)
        }
        .animation(.easeOut(duration: 1.2).delay(0.1), value: appeared)
        .allowsHitTesting(false)
    }

    // MARK: - Landing

    private var landingView: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandBlock
                .padding(.horizontal, 28)

            Spacer().frame(height: 40)

            featureStack
                .padding(.horizontal, 28)

            Spacer().frame(height: 40)

            authStack
                .padding(.horizontal, 28)

            Spacer().frame(height: 24)

            legal
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var brandBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppTheme.bronzeGradient)
                        .frame(width: 40, height: 40)
                        .shadow(color: AppTheme.accent.opacity(0.4), radius: 12, y: 6)
                    Image(systemName: "scissors")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                }
                Text("BRAIDERPANEL")
                    .font(AppTheme.sans(11, weight: .bold))
                    .tracking(2.8)
                    .foregroundColor(AppTheme.accentDeep)
            }

            Text("Run your\nbraid business.")
                .font(AppTheme.serif(34))
                .lineSpacing(-2)
                .foregroundColor(AppTheme.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(2)

            Text("Manage your profile, services, and bookings — all in one place.")
                .font(AppTheme.sans(14))
                .foregroundColor(AppTheme.slate)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 22)
    }

    private var featureStack: some View {
        VStack(spacing: 12) {
            featureRow(icon: "person.crop.circle.fill",
                       title: "Your profile, your rules",
                       subtitle: "Control what customers see")
            featureRow(icon: "photo.stack.fill",
                       title: "Portfolio that sells",
                       subtitle: "Upload and reorder your best work")
            featureRow(icon: "calendar.badge.clock",
                       title: "Availability on your terms",
                       subtitle: "Set dates and times that suit you")
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 26)
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(AppTheme.accentSoft).frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.sans(14, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                Text(subtitle)
                    .font(AppTheme.sans(12))
                    .foregroundColor(AppTheme.slate)
            }
            Spacer()
        }
        .padding(14)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.hairline.opacity(0.5), lineWidth: 0.5)
        )
    }

    private var authStack: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: "Create account", icon: "arrow.right") {
                Haptics.soft()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    mode = .signup
                }
            }

            SecondaryButton(title: "Log in") {
                Haptics.soft()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    mode = .login
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 28)
    }

    private var legal: some View {
        Text("By continuing you agree to our ")
            .font(AppTheme.sans(12))
            .foregroundColor(AppTheme.stone)
        + Text("Terms")
            .font(AppTheme.sans(12, weight: .semibold))
            .foregroundColor(AppTheme.slate)
        + Text(" and ")
            .font(AppTheme.sans(12))
            .foregroundColor(AppTheme.stone)
        + Text("Privacy Policy.")
            .font(AppTheme.sans(12, weight: .semibold))
            .foregroundColor(AppTheme.slate)
    }

    private func startEntrance() {
        withAnimation(.spring(response: 1.0, dampingFraction: 0.85).delay(0.1)) {
            appeared = true
        }
    }
}
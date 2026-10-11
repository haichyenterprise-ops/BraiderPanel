import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject private var session: SessionManager

    @State private var needsOnboarding = false
    @State private var isCheckingProfile = true

    var body: some View {
        Group {
            if !session.isInitialized || isCheckingProfile {
                splash
            } else if !session.isSignedIn {
                AuthView()
                    .transition(.opacity)
            } else if needsOnboarding {
                OnboardingFlow {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                        needsOnboarding = false
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                MainTabView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(AppTheme.cloud.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.5), value: session.isSignedIn)
        .animation(.easeInOut(duration: 0.5), value: needsOnboarding)
        .task(id: session.uid) {
            await checkOnboarding()
        }
    }

    private var splash: some View {
        ZStack {
            AppTheme.cloud.ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(AppTheme.bronzeGradient)
                        .frame(width: 88, height: 88)
                        .shadow(color: AppTheme.accent.opacity(0.4), radius: 20, y: 10)
                    Image(systemName: "scissors")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundColor(.white)
                }

                VStack(spacing: 6) {
                    Text("BraiderPanel")
                        .font(AppTheme.serif(30))
                        .foregroundColor(AppTheme.ink)
                    Text("Your business, in your hands.")
                        .font(AppTheme.sans(14))
                        .foregroundColor(AppTheme.slate)
                }

                ProgressView()
                    .tint(AppTheme.accent)
                    .padding(.top, 8)
            }
        }
    }

    private func checkOnboarding() async {
        guard session.isSignedIn else {
            await MainActor.run {
                needsOnboarding = false
                isCheckingProfile = true
            }
            return
        }

        let uid = session.uid
        guard !uid.isEmpty else { return }

        do {
            let snap = try await FirebaseManager.shared.db
                .collection("braiders")
                .document(uid)
                .getDocument()

            let onboarded = (snap.data()?["onboarded"] as? Bool) ?? false

            await MainActor.run {
                needsOnboarding = !onboarded
                isCheckingProfile = false
            }
        } catch {
            print("[ContentView] onboarding check failed:", error)
            await MainActor.run {
                needsOnboarding = true
                isCheckingProfile = false
            }
        }
    }
}
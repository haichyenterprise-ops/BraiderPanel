import SwiftUI

struct ShareProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared

    @State private var copied = false
    @State private var appeared = false

    private var shareURL: String {
        let uid = session.uid
        return "https://braidme.app/braider/\(uid)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.cloud.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    // Icon
                    ZStack {
                        Circle().fill(AppTheme.accentSoft).frame(width: 100, height: 100)
                        Circle().fill(AppTheme.accent.opacity(0.15)).frame(width: 76, height: 76)
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(AppTheme.accent)
                    }
                    .scaleEffect(appeared ? 1 : 0.85)
                    .opacity(appeared ? 1 : 0)

                    VStack(spacing: 8) {
                        Text("Share your profile")
                            .font(AppTheme.serif(26))
                            .foregroundColor(AppTheme.ink)
                        Text("Send this link to customers so they can find you on BraidMe.")
                            .font(AppTheme.sans(14))
                            .foregroundColor(AppTheme.slate)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal, 40)
                    }
                    .opacity(appeared ? 1 : 0)

                    // URL card
                    HStack(spacing: 12) {
                        Image(systemName: "link")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.accent)

                        Text(shareURL)
                            .font(AppTheme.mono(13))
                            .foregroundColor(AppTheme.ink)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Button {
                            UIPasteboard.general.string = shareURL
                            Haptics.success()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                copied = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation { copied = false }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 11, weight: .bold))
                                Text(copied ? "Copied" : "Copy")
                                    .font(AppTheme.sans(11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(copied ? AppTheme.success : AppTheme.ink, in: Capsule())
                        }
                        .buttonStyle(SoftPress())
                    }
                    .padding(16)
                    .background(AppTheme.snow)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.hairline, lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)

                    // Share button
                    Button {
                        Haptics.medium()
                        shareViaSystem()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Share via…")
                                .font(AppTheme.sans(17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppTheme.inkGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: AppTheme.ink.opacity(0.28), radius: 18, y: 10)
                    }
                    .buttonStyle(SoftPress())
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)

                    Spacer()
                }
            }
            .navigationTitle("Share")
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
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
        }
    }

    private func shareViaSystem() {
        let activity = UIActivityViewController(
            activityItems: [shareURL],
            applicationActivities: nil
        )
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        root.present(activity, animated: true)
    }
}
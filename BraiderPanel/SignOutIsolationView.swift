import SwiftUI

struct SignOutIsolationView: View {
    let appName: String
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            AppTheme.cloud.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(AppTheme.bronzeSoft)
                        .frame(width: 100, height: 100)
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 42))
                        .foregroundColor(AppTheme.accent)
                }

                VStack(spacing: 10) {
                    Text("Session closed")
                        .font(AppTheme.serif(26))
                        .foregroundColor(AppTheme.ink)
                    Text("Your \(appName) session has been signed out on this device. Tap continue to sign in again.")
                        .font(AppTheme.sans(14))
                        .foregroundColor(AppTheme.slate)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 40)
                }

                Spacer()

                PrimaryButton(title: "Continue", icon: "arrow.right") {
                    onContinue()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}
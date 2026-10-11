import SwiftUI

struct EditProfileSheet: View {
    let braider: Braider

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager

    @State private var name: String
    @State private var tagline: String
    @State private var bio: String
    @State private var story: String
    @State private var city: String
    @State private var yearsExperience: Int
    @State private var responseTime: String
    @State private var avatarUrl: String
    @State private var coverUrl: String

    @State private var saving = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    private let responseTimes = ["~5 min", "~10 min", "~15 min", "~30 min", "~1 hour", "~1 day"]

    init(braider: Braider) {
        self.braider = braider
        _name = State(initialValue: braider.name)
        _tagline = State(initialValue: braider.tagline)
        _bio = State(initialValue: braider.bio)
        _story = State(initialValue: braider.story)
        _city = State(initialValue: braider.city)
        _yearsExperience = State(initialValue: braider.yearsExperience)
        _responseTime = State(initialValue: braider.responseTime)
        _avatarUrl = State(initialValue: braider.avatarUrl)
        _coverUrl = State(initialValue: braider.coverUrl)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.cloud.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        coverPicker
                        avatarPicker
                        identitySection
                        storySection
                        metaSection
                        saveButton
                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(AppTheme.sans(15, weight: .medium))
                        .foregroundColor(AppTheme.slate)
                }
            }
            .alert("Couldn't save", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("Saved", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your profile has been updated.")
            }
        }
    }

    // MARK: - Cover

    private var coverPicker: some View {
        PhotoPickerButton { isUploading in
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if coverUrl.isEmpty {
                        AppTheme.inkGradient
                            .frame(height: 180)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 32, weight: .light))
                                        .foregroundColor(.white.opacity(0.5))
                                    Text("Tap to add cover photo")
                                        .font(AppTheme.sans(13, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            )
                    } else {
                        RemoteImage(url: coverUrl)
                            .frame(height: 180)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                )

                HStack(spacing: 6) {
                    if isUploading {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Text(isUploading ? "Uploading…" : "Change cover")
                        .font(AppTheme.sans(12, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.ink.opacity(0.85), in: Capsule())
                .padding(12)
            }
        } onUploaded: { url in
            coverUrl = url
        }
    }

    // MARK: - Avatar

    private var avatarPicker: some View {
        HStack(spacing: 20) {
            PhotoPickerButton { isUploading in
                ZStack {
                    Circle()
                        .stroke(AppTheme.accent, lineWidth: 3)
                        .frame(width: 108, height: 108)

                    if avatarUrl.isEmpty {
                        ZStack {
                            Circle().fill(AppTheme.inkGradient)
                            Image(systemName: "person.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white.opacity(0.75))
                        }
                        .frame(width: 96, height: 96)
                    } else {
                        RemoteImage(url: avatarUrl)
                            .frame(width: 96, height: 96)
                            .clipShape(Circle())
                    }

                    if isUploading {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 96, height: 96)
                        ProgressView().tint(.white)
                    }

                    // Camera badge
                    ZStack {
                        Circle().fill(AppTheme.ink).frame(width: 32, height: 32)
                            .overlay(Circle().stroke(AppTheme.snow, lineWidth: 3))
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 36, y: 36)
                }
            } onUploaded: { url in
                avatarUrl = url
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Profile picture")
                    .font(AppTheme.sans(15, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                Text("Tap the image to change it. This is what customers see on the map.")
                    .font(AppTheme.sans(12))
                    .foregroundColor(AppTheme.slate)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Identity

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Identity")

            FieldRow(icon: "person.fill", placeholder: "Full name", text: $name,
                     contentType: .name, submitLabel: .done)
            FieldRow(icon: "text.alignleft", placeholder: "Tagline (e.g. Knotless artisan · 5 yrs)",
                     text: $tagline, submitLabel: .done)
            FieldRow(icon: "text.alignleft", placeholder: "Short bio (1–2 lines)",
                     text: $bio, submitLabel: .done)
        }
    }

    // MARK: - Story

    private var storySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Your story")

            ZStack(alignment: .topLeading) {
                if story.isEmpty {
                    Text("Tell customers how you started, what you love about braiding, and why they should book you.")
                        .font(AppTheme.sans(15))
                        .foregroundColor(AppTheme.stone.opacity(0.7))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $story)
                    .font(AppTheme.sans(15))
                    .foregroundColor(AppTheme.ink)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(minHeight: 160)
                    .autocorrectionDisabled(false)
            }
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            )
        }
    }

    // MARK: - Meta

    private var metaSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Details")

            FieldRow(icon: "mappin.and.ellipse", placeholder: "City", text: $city,
                     contentType: .addressCity, submitLabel: .done)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("YEARS EXPERIENCE")
                        .font(AppTheme.sans(10, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(AppTheme.stone)
                    HStack(spacing: 12) {
                        Button {
                            Haptics.select()
                            yearsExperience = max(0, yearsExperience - 1)
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.ink)
                                .frame(width: 36, height: 36)
                                .background(AppTheme.mist, in: Circle())
                        }
                        Text("\(yearsExperience)")
                            .font(AppTheme.serif(24))
                            .foregroundColor(AppTheme.ink)
                            .frame(minWidth: 40)
                            .contentTransition(.numericText())
                        Button {
                            Haptics.select()
                            yearsExperience = min(60, yearsExperience + 1)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(AppTheme.ink, in: Circle())
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(AppTheme.snow)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.hairline, lineWidth: 1)
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("RESPONSE TIME")
                    .font(AppTheme.sans(10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(AppTheme.stone)
                    .padding(.horizontal, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(responseTimes, id: \.self) { time in
                            Button {
                                Haptics.select()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    responseTime = time
                                }
                            } label: {
                                Text(time)
                                    .font(AppTheme.sans(13, weight: .semibold))
                                    .foregroundColor(responseTime == time ? .white : AppTheme.ink)
                                    .padding(.horizontal, 14)
                                    .frame(height: 36)
                                    .background(responseTime == time ? AppTheme.ink : AppTheme.snow, in: Capsule())
                                    .overlay(
                                        Capsule().stroke(
                                            responseTime == time ? Color.clear : AppTheme.hairline,
                                            lineWidth: 1
                                        )
                                    )
                            }
                            .buttonStyle(SoftPress())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        PrimaryButton(title: saving ? "Saving…" : "Save changes",
                      icon: "checkmark",
                      loading: saving) {
            save()
        }
        .disabled(saving)
        .padding(.top, 8)
    }

    private func save() {
        let uid = session.uid
        guard !uid.isEmpty else { return }
        saving = true
        Haptics.medium()

        Task {
            do {
                try await FirebaseManager.shared.updateBraider(uid: uid, data: [
                    "name": name.trimmingCharacters(in: .whitespaces),
                    "tagline": tagline,
                    "bio": bio,
                    "story": story,
                    "city": city,
                    "yearsExperience": yearsExperience,
                    "responseTime": responseTime,
                    "avatarUrl": avatarUrl,
                    "coverUrl": coverUrl
                ])
                await MainActor.run {
                    saving = false
                    Haptics.success()
                    showSuccess = true
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
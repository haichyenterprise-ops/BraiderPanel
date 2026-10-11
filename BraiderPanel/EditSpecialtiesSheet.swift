import SwiftUI

struct EditSpecialtiesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared

    @State private var specialties: [String] = []
    @State private var newSpecialty = ""
    @State private var saving = false
    @State private var errorMessage: String?

    private let suggestions = [
        "Knotless", "Box Braids", "Cornrows", "Boho", "Twists",
        "Locs", "Feed-in", "Jumbo", "Fulani", "Passion Twists",
        "Kids", "Natural Hair", "Edges"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.cloud.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            currentSection
                            addSection
                            suggestionsSection
                            Color.clear.frame(height: 40)
                        }
                        .padding(20)
                    }

                    footer
                }
            }
            .navigationTitle("Specialties")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(AppTheme.sans(15, weight: .medium))
                        .foregroundColor(AppTheme.slate)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .onAppear {
            specialties = fb.myBraider?.specialties ?? []
        }
    }

    // MARK: - Current

    private var currentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: "Your specialties")
                Spacer()
                Text("\(specialties.count)")
                    .font(AppTheme.sans(11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(AppTheme.accent, in: Circle())
            }

            if specialties.isEmpty {
                Text("Add specialties to help customers find you.")
                    .font(AppTheme.sans(14))
                    .foregroundColor(AppTheme.stone)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(specialties, id: \.self) { s in
                        HStack(spacing: 8) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppTheme.accent)
                            Text(s)
                                .font(AppTheme.sans(13, weight: .semibold))
                                .foregroundColor(AppTheme.ink)
                            Button {
                                Haptics.soft()
                                withAnimation {
                                    specialties.removeAll { $0 == s }
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(AppTheme.stone)
                                    .padding(4)
                            }
                        }
                        .padding(.leading, 12)
                        .padding(.trailing, 6)
                        .frame(height: 36)
                        .background(AppTheme.accentSoft, in: Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Add

    private var addSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Add your own")

            HStack(spacing: 10) {
                TextField("e.g. Micro Braids", text: $newSpecialty)
                    .font(AppTheme.sans(15, weight: .medium))
                    .foregroundColor(AppTheme.ink)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(AppTheme.snow)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppTheme.hairline, lineWidth: 1)
                    )
                    .submitLabel(.done)
                    .onSubmit { addCustom() }

                Button {
                    addCustom()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 52, height: 52)
                        .background(canAdd ? AppTheme.ink : AppTheme.stone, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!canAdd)
                .buttonStyle(SoftPress())
            }
        }
    }

    private var canAdd: Bool {
        let trimmed = newSpecialty.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && !specialties.contains(trimmed)
    }

    // MARK: - Suggestions

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Suggestions")

            FlowLayout(spacing: 8) {
                ForEach(suggestions, id: \.self) { s in
                    let isOn = specialties.contains(s)
                    Button {
                        Haptics.select()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                            if isOn {
                                specialties.removeAll { $0 == s }
                            } else {
                                specialties.append(s)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isOn {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text(s)
                                .font(AppTheme.sans(13, weight: .semibold))
                                .foregroundColor(isOn ? .white : AppTheme.ink)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(isOn ? AppTheme.ink : AppTheme.snow, in: Capsule())
                        .overlay(
                            Capsule().stroke(
                                isOn ? Color.clear : AppTheme.hairline,
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(SoftPress())
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [AppTheme.cloud.opacity(0), AppTheme.cloud, AppTheme.cloud],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 30)

            PrimaryButton(
                title: saving ? "Saving…" : "Save specialties",
                icon: "checkmark",
                loading: saving
            ) {
                save()
            }
            .disabled(saving)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .background(AppTheme.cloud)
        }
    }

    // MARK: - Actions

    private func addCustom() {
        let trimmed = newSpecialty.trimmingCharacters(in: .whitespaces)
        guard canAdd else { return }
        Haptics.success()
        withAnimation {
            specialties.append(trimmed)
            newSpecialty = ""
        }
    }

    private func save() {
        let uid = session.uid
        guard !uid.isEmpty else { return }
        saving = true
        Haptics.medium()

        Task {
            do {
                try await FirebaseManager.shared.updateBraider(uid: uid, data: [
                    "specialties": specialties
                ])
                await MainActor.run {
                    saving = false
                    Haptics.success()
                    dismiss()
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
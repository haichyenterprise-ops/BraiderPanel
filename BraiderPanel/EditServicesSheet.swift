import SwiftUI

struct EditServicesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared

    @State private var services: [BraidService] = []
    @State private var editingService: BraidService?
    @State private var saving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.cloud.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if services.isEmpty {
                        emptyState
                    } else {
                        listView
                    }

                    footer
                }
            }
            .navigationTitle("Services")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(AppTheme.sans(15, weight: .medium))
                        .foregroundColor(AppTheme.slate)
                }
            }
            .sheet(item: $editingService) { service in
                EditServiceDetailSheet(service: service) { updated in
                    if let idx = services.firstIndex(where: { $0.id == updated.id }) {
                        services[idx] = updated
                    } else {
                        services.append(updated)
                    }
                    editingService = nil
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
            services = fb.myBraider?.services ?? []
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("What you offer")
                    .font(AppTheme.serif(22))
                    .foregroundColor(AppTheme.ink)
                Text("\(services.count) service\(services.count == 1 ? "" : "s") · at least 1 required to go live")
                    .font(AppTheme.sans(12))
                    .foregroundColor(AppTheme.slate)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle().fill(AppTheme.accentSoft).frame(width: 100, height: 100)
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(AppTheme.accent)
            }

            VStack(spacing: 8) {
                Text("Add your first service")
                    .font(AppTheme.serif(24))
                    .foregroundColor(AppTheme.ink)
                Text("Each service has a name, price, duration, description, and photo.")
                    .font(AppTheme.sans(14))
                    .foregroundColor(AppTheme.slate)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

    private var listView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(services) { service in
                    ServiceEditableRow(service: service) {
                        Haptics.soft()
                        editingService = service
                    } onDelete: {
                        Haptics.warning()
                        withAnimation {
                            services.removeAll { $0.id == service.id }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Footer (add button always visible)

    private var footer: some View {
        VStack(spacing: 10) {
            if !services.isEmpty && services.allSatisfy({ $0.name.isEmpty || $0.imageUrl.isEmpty }) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.warn)
                    Text("At least one service needs a name and photo to go live.")
                        .font(AppTheme.sans(12, weight: .medium))
                        .foregroundColor(AppTheme.warn)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Add another service — always visible now
            Button {
                Haptics.medium()
                editingService = BraidService.empty()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("Add \(services.isEmpty ? "your first" : "another") service")
                        .font(AppTheme.sans(15, weight: .semibold))
                }
                .foregroundColor(AppTheme.accentDeep)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppTheme.accent.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(SoftPress())

            PrimaryButton(
                title: saving ? "Saving…" : "Save services",
                icon: "checkmark",
                loading: saving
            ) {
                save()
            }
            .disabled(saving)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(AppTheme.cloud)
    }

    private func save() {
        let uid = session.uid
        guard !uid.isEmpty else { return }
        saving = true
        Haptics.medium()

        let dicts = services.map { $0.dictionary }
        let minPrice = services.map { $0.priceFrom }.filter { $0 > 0 }.min() ?? 0
        let hasValid = services.contains { !$0.name.isEmpty && !$0.imageUrl.isEmpty }

        Task {
            do {
                try await FirebaseManager.shared.updateBraider(uid: uid, data: [
                    "services": dicts,
                    "priceFrom": minPrice,
                    "published": hasValid
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

// MARK: - Service editable row

struct ServiceEditableRow: View {
    let service: BraidService
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    if service.imageUrl.isEmpty {
                        RoundedRectangle(cornerRadius: 12).fill(AppTheme.mist)
                            .frame(width: 64, height: 64)
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.ash)
                    } else {
                        RemoteImage(url: service.imageUrl)
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(service.name.isEmpty ? "Untitled" : service.name)
                            .font(AppTheme.sans(15, weight: .semibold))
                            .foregroundColor(service.name.isEmpty ? AppTheme.stone : AppTheme.ink)
                            .italic(service.name.isEmpty)
                            .lineLimit(1)

                        if service.popular {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.gold)
                        }
                    }

                    HStack(spacing: 10) {
                        Text("£\(service.priceFrom)")
                            .font(AppTheme.sans(13, weight: .bold))
                            .foregroundColor(AppTheme.accentDeep)
                        Text("·")
                            .foregroundColor(AppTheme.stone)
                        Text("\(service.durationMinutes / 60)h \(service.durationMinutes % 60)m")
                            .font(AppTheme.sans(12))
                            .foregroundColor(AppTheme.slate)
                    }

                    if !service.availableDates.isEmpty {
                        Text("\(service.availableDates.count) date\(service.availableDates.count == 1 ? "" : "s") available")
                            .font(AppTheme.sans(11))
                            .foregroundColor(AppTheme.sage)
                    } else {
                        Text("No availability set")
                            .font(AppTheme.sans(11))
                            .foregroundColor(AppTheme.warn)
                    }
                }

                Spacer()

                Menu {
                    Button {
                        onTap()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.stone)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.mist, in: Circle())
                }
            }
            .padding(14)
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.hairline.opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(CardPress())
    }
}
import SwiftUI

struct EditPortfolioSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared

    @State private var items: [PortfolioItem] = []
    @State private var editingItem: PortfolioItem?
    @State private var saving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.cloud.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if items.isEmpty {
                        emptyState
                    } else {
                        listView
                    }

                    footer
                }
            }
            .navigationTitle("Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(AppTheme.sans(15, weight: .medium))
                        .foregroundColor(AppTheme.slate)
                }
            }
            .sheet(item: $editingItem) { item in
                EditPortfolioItemSheet(item: item) { updated in
                    if let idx = items.firstIndex(where: { $0.id == updated.id }) {
                        items[idx] = updated
                    }
                    editingItem = nil
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
            items = fb.myBraider?.portfolio ?? []
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Your work")
                    .font(AppTheme.serif(22))
                    .foregroundColor(AppTheme.ink)
                Text("\(items.count) photo\(items.count == 1 ? "" : "s") · drag to reorder")
                    .font(AppTheme.sans(12))
                    .foregroundColor(AppTheme.slate)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle().fill(AppTheme.accentSoft).frame(width: 100, height: 100)
                Image(systemName: "photo.stack")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(AppTheme.accent)
            }

            VStack(spacing: 8) {
                Text("Build your portfolio")
                    .font(AppTheme.serif(24))
                    .foregroundColor(AppTheme.ink)
                Text("Add photos of your braids. The first photo becomes the header image customers see.")
                    .font(AppTheme.sans(14))
                    .foregroundColor(AppTheme.slate)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

    // MARK: - List

    private var listView: some View {
        List {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                PortfolioRow(item: item, index: idx)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Haptics.warning()
                            withAnimation {
                                items.removeAll { $0.id == item.id }
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .onTapGesture {
                        Haptics.soft()
                        editingItem = item
                    }
            }
            .onMove { from, to in
                Haptics.select()
                items.move(fromOffsets: from, toOffset: to)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            MultiPhotoPickerButton { urls in
                let newItems = urls.map { url -> PortfolioItem in
                    PortfolioItem(
                        id: UUID().uuidString,
                        imageUrl: url,
                        caption: "",
                        tag: "",
                        likes: 0
                    )
                }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    items.append(contentsOf: newItems)
                }
            }

            PrimaryButton(
                title: saving ? "Saving…" : "Save portfolio",
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

    // MARK: - Save

    private func save() {
        let uid = session.uid
        guard !uid.isEmpty else { return }
        saving = true
        Haptics.medium()

        let dicts = items.map { $0.dictionary }

        Task {
            do {
                try await FirebaseManager.shared.updateBraider(uid: uid, data: [
                    "portfolio": dicts
                ])

                // Update cover to first portfolio image if it's empty
                if let first = items.first, !first.imageUrl.isEmpty,
                   (fb.myBraider?.coverUrl.isEmpty ?? true) {
                    try await FirebaseManager.shared.updateBraider(uid: uid, data: [
                        "coverUrl": first.imageUrl
                    ])
                }

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

// MARK: - Portfolio row

struct PortfolioRow: View {
    let item: PortfolioItem
    let index: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .topLeading) {
                RemoteImage(url: item.imageUrl)
                    .frame(width: 90, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                Text("#\(index + 1)")
                    .font(AppTheme.sans(10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppTheme.ink.opacity(0.85), in: Capsule())
                    .padding(6)
            }

            VStack(alignment: .leading, spacing: 4) {
                if item.caption.isEmpty {
                    Text("Untitled")
                        .font(AppTheme.sans(14, weight: .semibold))
                        .foregroundColor(AppTheme.stone)
                        .italic()
                } else {
                    Text(item.caption)
                        .font(AppTheme.sans(14, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                        .lineLimit(2)
                }

                if !item.tag.isEmpty {
                    Text(item.tag)
                        .font(AppTheme.sans(11, weight: .medium))
                        .foregroundColor(AppTheme.accentDeep)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.accentSoft, in: Capsule())
                }
            }

            Spacer()
        }
        .padding(10)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.hairline.opacity(0.5), lineWidth: 0.5)
        )
    }
}

// MARK: - Edit portfolio item

struct EditPortfolioItemSheet: View {
    let item: PortfolioItem
    let onSave: (PortfolioItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var caption: String
    @State private var tag: String
    @State private var imageUrl: String

    private let tagOptions = ["Knotless", "Box Braids", "Cornrows", "Boho", "Twists", "Locs", "Feed-in", "Jumbo", "Kids"]

    init(item: PortfolioItem, onSave: @escaping (PortfolioItem) -> Void) {
        self.item = item
        self.onSave = onSave
        _caption = State(initialValue: item.caption)
        _tag = State(initialValue: item.tag)
        _imageUrl = State(initialValue: item.imageUrl)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.cloud.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Image preview + replace
                        PhotoPickerButton { isUploading in
                            ZStack(alignment: .bottomTrailing) {
                                if imageUrl.isEmpty {
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(AppTheme.mist)
                                        .frame(height: 260)
                                        .overlay(
                                            VStack(spacing: 8) {
                                                Image(systemName: "photo")
                                                    .font(.system(size: 36, weight: .light))
                                                    .foregroundColor(AppTheme.ash)
                                                Text("Tap to add photo")
                                                    .font(AppTheme.sans(13, weight: .medium))
                                                    .foregroundColor(AppTheme.stone)
                                            }
                                        )
                                } else {
                                    RemoteImage(url: imageUrl)
                                        .frame(height: 260)
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                }

                                HStack(spacing: 6) {
                                    if isUploading {
                                        ProgressView().tint(.white).scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    Text(isUploading ? "Uploading…" : "Replace")
                                        .font(AppTheme.sans(12, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppTheme.ink.opacity(0.85), in: Capsule())
                                .padding(12)
                            }
                        } onUploaded: { url in
                            imageUrl = url
                        }

                        // Caption
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Caption")
                            FieldRow(icon: "text.alignleft",
                                     placeholder: "e.g. Waist-length knotless",
                                     text: $caption, submitLabel: .done)
                        }

                        // Tag
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(text: "Category")
                            FlowLayout(spacing: 8) {
                                ForEach(tagOptions, id: \.self) { option in
                                    Button {
                                        Haptics.select()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                            tag = tag == option ? "" : option
                                        }
                                    } label: {
                                        Text(option)
                                            .font(AppTheme.sans(13, weight: .semibold))
                                            .foregroundColor(tag == option ? .white : AppTheme.ink)
                                            .padding(.horizontal, 14)
                                            .frame(height: 36)
                                            .background(tag == option ? AppTheme.ink : AppTheme.snow, in: Capsule())
                                            .overlay(
                                                Capsule().stroke(
                                                    tag == option ? Color.clear : AppTheme.hairline,
                                                    lineWidth: 1
                                                )
                                            )
                                    }
                                    .buttonStyle(SoftPress())
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(AppTheme.sans(15, weight: .medium))
                        .foregroundColor(AppTheme.slate)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Haptics.success()
                        let updated = PortfolioItem(
                            id: item.id,
                            imageUrl: imageUrl,
                            caption: caption,
                            tag: tag,
                            likes: item.likes
                        )
                        onSave(updated)
                    }
                    .font(AppTheme.sans(15, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                    .disabled(imageUrl.isEmpty)
                }
            }
        }
    }
}
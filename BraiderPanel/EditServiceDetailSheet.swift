import SwiftUI

struct EditServiceDetailSheet: View {
    let service: BraidService
    let onSave: (BraidService) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var description: String
    @State private var imageUrl: String
    @State private var priceFrom: Int
    @State private var durationMinutes: Int
    @State private var popular: Bool
    @State private var includes: [String]
    @State private var newInclude = ""

    init(service: BraidService, onSave: @escaping (BraidService) -> Void) {
        self.service = service
        self.onSave = onSave
        _name = State(initialValue: service.name)
        _description = State(initialValue: service.description)
        _imageUrl = State(initialValue: service.imageUrl)
        _priceFrom = State(initialValue: service.priceFrom)
        _durationMinutes = State(initialValue: service.durationMinutes)
        _popular = State(initialValue: service.popular)
        _includes = State(initialValue: service.includes)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !imageUrl.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.cloud.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        imageBlock
                        nameBlock
                        priceAndDuration
                        descriptionBlock
                        includesBlock
                        popularToggle
                        Color.clear.frame(height: 40)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(name.isEmpty ? "New service" : name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(AppTheme.sans(15, weight: .medium))
                        .foregroundColor(AppTheme.slate)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .font(AppTheme.sans(15, weight: .semibold))
                        .foregroundColor(isValid ? AppTheme.ink : AppTheme.stone)
                        .disabled(!isValid)
                }
            }
        }
    }

    // MARK: - Image

    private var imageBlock: some View {
        PhotoPickerButton { isUploading in
            ZStack(alignment: .bottomTrailing) {
                if imageUrl.isEmpty {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AppTheme.mist)
                        .frame(height: 220)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "photo")
                                    .font(.system(size: 36, weight: .light))
                                    .foregroundColor(AppTheme.ash)
                                Text("Add service photo")
                                    .font(AppTheme.sans(13, weight: .medium))
                                    .foregroundColor(AppTheme.stone)
                            }
                        )
                } else {
                    RemoteImage(url: imageUrl)
                        .frame(height: 220)
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
                    Text(isUploading ? "Uploading…" : "Change photo")
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
    }

    // MARK: - Name

    private var nameBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Service name")
            FieldRow(icon: "textformat",
                     placeholder: "e.g. Knotless Braids",
                     text: $name,
                     submitLabel: .done)
        }
    }

    // MARK: - Price + Duration

    private var priceAndDuration: some View {
        HStack(spacing: 12) {
            stepperCard(
                title: "PRICE",
                value: "£\(priceFrom)",
                onMinus: { priceFrom = max(0, priceFrom - 5) },
                onPlus: { priceFrom += 5 }
            )

            stepperCard(
                title: "DURATION",
                value: "\(durationMinutes / 60)h \(durationMinutes % 60)m",
                onMinus: { durationMinutes = max(30, durationMinutes - 30) },
                onPlus: { durationMinutes += 30 }
            )
        }
    }

    private func stepperCard(title: String, value: String, onMinus: @escaping () -> Void, onPlus: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppTheme.sans(10, weight: .bold))
                .tracking(1.4)
                .foregroundColor(AppTheme.stone)

            HStack(spacing: 10) {
                Button {
                    Haptics.select()
                    onMinus()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.ink)
                        .frame(width: 30, height: 30)
                        .background(AppTheme.mist, in: Circle())
                }

                Text(value)
                    .font(AppTheme.serif(17))
                    .foregroundColor(AppTheme.ink)
                    .frame(minWidth: 60)
                    .contentTransition(.numericText())

                Button {
                    Haptics.select()
                    onPlus()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(AppTheme.ink, in: Circle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
    }

    // MARK: - Description

    private var descriptionBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Description")
            ZStack(alignment: .topLeading) {
                if description.isEmpty {
                    Text("Describe what the customer gets — technique, style, finish.")
                        .font(AppTheme.sans(15))
                        .foregroundColor(AppTheme.stone.opacity(0.7))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $description)
                    .font(AppTheme.sans(15))
                    .foregroundColor(AppTheme.ink)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(minHeight: 120)
            }
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            )
        }
    }

    // MARK: - Includes

    private var includesBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "What's included")

            FlowLayout(spacing: 8) {
                ForEach(includes, id: \.self) { item in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppTheme.accent)
                        Text(item)
                            .font(AppTheme.sans(13, weight: .medium))
                            .foregroundColor(AppTheme.ink)
                        Button {
                            Haptics.soft()
                            withAnimation {
                                includes.removeAll { $0 == item }
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(AppTheme.stone)
                                .padding(4)
                        }
                    }
                    .padding(.leading, 10)
                    .padding(.trailing, 6)
                    .frame(height: 34)
                    .background(AppTheme.accentSoft, in: Capsule())
                }

                if !newInclude.isEmpty {
                    HStack(spacing: 6) {
                        TextField("", text: $newInclude)
                            .font(AppTheme.sans(13, weight: .medium))
                            .foregroundColor(AppTheme.ink)
                            .frame(width: 80)
                        Button {
                            addInclude()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(AppTheme.accent, in: Circle())
                        }
                    }
                    .padding(.leading, 10)
                    .padding(.trailing, 6)
                    .frame(height: 34)
                    .background(AppTheme.accentSoft, in: Capsule())
                } else {
                    Button {
                        Haptics.soft()
                        newInclude = " "
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("Add item")
                                .font(AppTheme.sans(13, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.accentDeep)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(AppTheme.accentSoft, in: Capsule())
                        .overlay(Capsule().stroke(AppTheme.accent.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(SoftPress())
                }
            }

            if !newInclude.isEmpty {
                HStack(spacing: 10) {
                    TextField("e.g. Hair included", text: $newInclude)
                        .font(AppTheme.sans(14))
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(AppTheme.snow)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.hairline, lineWidth: 1)
                        )
                    Button {
                        addInclude()
                    } label: {
                        Text("Add")
                            .font(AppTheme.sans(13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(AppTheme.ink, in: Capsule())
                    }
                }
            }
        }
    }

    private func addInclude() {
        let trimmed = newInclude.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { newInclude = ""; return }
        Haptics.success()
        withAnimation {
            includes.append(trimmed)
            newInclude = ""
        }
    }

    // MARK: - Popular

    private var popularToggle: some View {
        Button {
            Haptics.select()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                popular.toggle()
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(popular ? AppTheme.gold.opacity(0.2) : AppTheme.mist)
                        .frame(width: 40, height: 40)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(popular ? AppTheme.gold : AppTheme.stone)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mark as popular")
                        .font(AppTheme.sans(15, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                    Text("Adds a badge so customers see it first")
                        .font(AppTheme.sans(12))
                        .foregroundColor(AppTheme.slate)
                }

                Spacer()

                Toggle("", isOn: $popular)
                    .labelsHidden()
                    .tint(AppTheme.ink)
                    .allowsHitTesting(false)
            }
            .padding(16)
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(CardPress())
    }

    // MARK: - Save

    private func save() {
        guard isValid else { return }
        Haptics.success()
        let updated = BraidService(
            id: service.id,
            name: name.trimmingCharacters(in: .whitespaces),
            description: description,
            imageUrl: imageUrl,
            priceFrom: priceFrom,
            durationMinutes: durationMinutes,
            includes: includes,
            popular: popular
        )
        onSave(updated)
    }
}
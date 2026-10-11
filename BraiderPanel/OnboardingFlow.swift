import SwiftUI

struct OnboardingFlow: View {
    var onComplete: () -> Void

    @EnvironmentObject private var session: SessionManager

    @State private var step = 0
    @State private var appeared = false
    @State private var saving = false
    @State private var errorMessage: String?

    // Collected data
    @State private var fullName = ""
    @State private var dob = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var privateAddress = Address.empty
    @State private var businessAddress = Address.empty
    @State private var sameAddress = false
    @State private var phone = ""

    private let totalSteps = 5

    var body: some View {
        ZStack {
            AppTheme.cloud.ignoresSafeArea()
            ambient

            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                TabView(selection: $step) {
                    NameStep(name: $fullName).tag(0)
                    DOBStep(dob: $dob).tag(1)
                    AddressStep(
                        title: "Private address",
                        subtitle: "Only visible to you. We use this for account verification.",
                        address: $privateAddress,
                        icon: "house.fill"
                    ).tag(2)
                    BusinessAddressStep(
                        address: $businessAddress,
                        sameAddress: $sameAddress,
                        privateAddress: privateAddress
                    ).tag(3)
                    PhoneStep(phone: $phone).tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: step)

                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
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
    }

    // MARK: - Ambient

    private var ambient: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [AppTheme.accent.opacity(0.14), .clear],
                    center: .center, startRadius: 0, endRadius: 200
                ))
                .frame(width: 420, height: 420)
                .blur(radius: 50)
                .offset(x: -140, y: -180)
                .opacity(appeared ? 1 : 0)

            Circle()
                .fill(RadialGradient(
                    colors: [AppTheme.plum.opacity(0.10), .clear],
                    center: .center, startRadius: 0, endRadius: 180
                ))
                .frame(width: 380, height: 380)
                .blur(radius: 60)
                .offset(x: 160, y: 260)
                .opacity(appeared ? 1 : 0)
        }
        .animation(.easeOut(duration: 1.2), value: appeared)
        .allowsHitTesting(false)
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("STEP \(step + 1) OF \(totalSteps)")
                    .font(AppTheme.sans(10, weight: .bold))
                    .tracking(1.6)
                    .foregroundColor(AppTheme.accentDeep)

                Spacer()

                Button {
                    Haptics.warning()
                    session.signOut()
                } label: {
                    Text("Cancel")
                        .font(AppTheme.sans(12, weight: .medium))
                        .foregroundColor(AppTheme.stone)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.hairline)
                    Capsule()
                        .fill(AppTheme.inkGradient)
                        .frame(width: geo.size.width * progress)
                        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: step)
                }
            }
            .frame(height: 5)
        }
    }

    private var progress: CGFloat {
        CGFloat(step + 1) / CGFloat(totalSteps)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button {
                    Haptics.soft()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        step -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                        .frame(width: 56, height: 56)
                        .background(AppTheme.snow, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppTheme.hairline, lineWidth: 1)
                        )
                }
                .buttonStyle(SoftPress())
            }

            PrimaryButton(
                title: step == totalSteps - 1 ? "Finish setup" : "Continue",
                icon: step == totalSteps - 1 ? "checkmark" : "arrow.right",
                loading: saving
            ) {
                advance()
            }
            .disabled(!canAdvance || saving)
            .opacity(canAdvance ? 1 : 0.4)
        }
    }

    // MARK: - Validation

    private var canAdvance: Bool {
        switch step {
        case 0: return fullName.trimmingCharacters(in: .whitespaces).count >= 2
        case 1: return true
        case 2: return !privateAddress.line1.isEmpty && !privateAddress.postcode.isEmpty
        case 3:
            if sameAddress {
                return true
            }
            return !businessAddress.line1.isEmpty && !businessAddress.postcode.isEmpty
        case 4: return phone.count >= 7
        default: return false
        }
    }

    // MARK: - Advance

    private func advance() {
        Haptics.medium()

        if step < totalSteps - 1 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                step += 1
            }
            return
        }

        // Final step — save to Firestore
        save()
    }

    private func save() {
        let uid = session.uid
        let email = session.email ?? ""

        guard !uid.isEmpty else {
            errorMessage = "Session expired. Please log in again."
            return
        }

        // If user ticked "same as private", use private as business
        let finalBusiness = sameAddress ? privateAddress : businessAddress

        saving = true
        Haptics.medium()

        var braider = Braider.draft(uid: uid, email: email)
        braider.name = fullName.trimmingCharacters(in: .whitespaces)
        braider.dateOfBirth = dob
        braider.privateAddress = privateAddress
        braider.businessAddress = finalBusiness
        braider.phone = phone
        braider.city = finalBusiness.city.isEmpty ? privateAddress.city : finalBusiness.city
        braider.onboarded = true
        braider.published = false   // will flip to true once a service is added

        Task {
            do {
                try await FirebaseManager.shared.createBraiderDoc(braider)
                await MainActor.run {
                    saving = false
                    Haptics.success()
                    onComplete()
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

// MARK: - Step 1: Name

struct NameStep: View {
    @Binding var name: String
    @State private var appeared = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 40)

            VStack(alignment: .leading, spacing: 14) {
                Text("What's your\nfull name?")
                    .font(AppTheme.serif(36))
                    .lineSpacing(-2)
                    .foregroundColor(AppTheme.ink)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)

                Text("This will appear on your public profile as your business name.")
                    .font(AppTheme.sans(15))
                    .foregroundColor(AppTheme.slate)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)

            Spacer().frame(height: 32)

            FieldRow(
                icon: "person.fill",
                placeholder: "e.g. Sarah Mensah",
                text: $name,
                contentType: .name,
                submitLabel: .done
            )
            .focused($focused)
            .padding(.horizontal, 28)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                focused = true
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }
}

// MARK: - Step 2: DOB

struct DOBStep: View {
    @Binding var dob: Date
    @State private var appeared = false

    private var years: Int {
        Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 40)

            VStack(alignment: .leading, spacing: 14) {
                Text("When were\nyou born?")
                    .font(AppTheme.serif(36))
                    .lineSpacing(-2)
                    .foregroundColor(AppTheme.ink)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)

                Text("You must be 18 or over to offer services on BraiderPanel.")
                    .font(AppTheme.sans(15))
                    .foregroundColor(AppTheme.slate)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)

            Spacer().frame(height: 32)

            VStack(spacing: 16) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(years)")
                        .font(.system(size: 68, weight: .bold, design: .serif))
                        .foregroundColor(years >= 18 ? AppTheme.ink : AppTheme.danger)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: years)
                    Text("years old")
                        .font(AppTheme.sans(18, weight: .medium))
                        .foregroundColor(AppTheme.slate)
                        .padding(.bottom, 10)
                }

                DatePicker("", selection: $dob,
                           in: Calendar.current.date(byAdding: .year, value: -100, to: Date())!...Date(),
                           displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 180)
                    .clipped()

                if years < 18 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.danger)
                        Text("You must be 18 or over to continue.")
                            .font(AppTheme.sans(13, weight: .medium))
                            .foregroundColor(AppTheme.danger)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppTheme.danger.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 28)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }
}

// MARK: - Step 3: Private address

struct AddressStep: View {
    let title: String
    let subtitle: String
    @Binding var address: Address
    let icon: String

    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 40)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(AppTheme.accentSoft).frame(width: 34, height: 34)
                            Image(systemName: icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.accent)
                        }
                        Text(title.uppercased())
                            .font(AppTheme.sans(11, weight: .bold))
                            .tracking(2.0)
                            .foregroundColor(AppTheme.accentDeep)
                    }

                    Text(title)
                        .font(AppTheme.serif(32))
                        .lineSpacing(-2)
                        .foregroundColor(AppTheme.ink)
                        .minimumScaleFactor(0.7)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(AppTheme.sans(14))
                        .foregroundColor(AppTheme.slate)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 24)

                VStack(spacing: 14) {
                    FieldRow(icon: "house.fill", placeholder: "Address line 1",
                             text: $address.line1, contentType: .streetAddressLine1)
                    FieldRow(icon: "house", placeholder: "Address line 2 (optional)",
                             text: $address.line2, contentType: .streetAddressLine2)
                    FieldRow(icon: "building.2.fill", placeholder: "City",
                             text: $address.city, contentType: .addressCity)
                    FieldRow(icon: "number", placeholder: "Postcode",
                             text: $address.postcode, contentType: .postalCode,
                             keyboard: .default)
                    FieldRow(icon: "globe.europe.africa.fill", placeholder: "Country",
                             text: $address.country, contentType: .countryName)
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 60)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }
}

// MARK: - Step 4: Business address

struct BusinessAddressStep: View {
    @Binding var address: Address
    @Binding var sameAddress: Bool
    let privateAddress: Address

    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 40)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(AppTheme.accentSoft).frame(width: 34, height: 34)
                            Image(systemName: "building.2.crop.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.accent)
                        }
                        Text("BUSINESS ADDRESS".uppercased())
                            .font(AppTheme.sans(11, weight: .bold))
                            .tracking(2.0)
                            .foregroundColor(AppTheme.accentDeep)
                    }

                    Text("Where do you\nwork from?")
                        .font(AppTheme.serif(32))
                        .lineSpacing(-2)
                        .foregroundColor(AppTheme.ink)
                        .minimumScaleFactor(0.7)
                        .lineLimit(2)

                    Text("This helps customers find you on the map.")
                        .font(AppTheme.sans(14))
                        .foregroundColor(AppTheme.slate)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 20)

                // Same address toggle
                Button {
                    Haptics.select()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        sameAddress.toggle()
                        if sameAddress {
                            address = privateAddress
                        }
                    }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(sameAddress ? AppTheme.accent : AppTheme.hairline, lineWidth: 2)
                                .frame(width: 24, height: 24)
                            if sameAddress {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(AppTheme.accent)
                                    .frame(width: 24, height: 24)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .heavy))
                                    .foregroundColor(.white)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Same as private address")
                                .font(AppTheme.sans(15, weight: .semibold))
                                .foregroundColor(AppTheme.ink)
                            Text("I work from home")
                                .font(AppTheme.sans(12))
                                .foregroundColor(AppTheme.slate)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(AppTheme.snow)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.hairline, lineWidth: 0.5)
                    )
                }
                .buttonStyle(SoftPress())
                .padding(.horizontal, 28)

                Spacer().frame(height: 20)

                if !sameAddress {
                    VStack(spacing: 14) {
                        FieldRow(icon: "house.fill", placeholder: "Address line 1",
                                 text: $address.line1, contentType: .streetAddressLine1)
                        FieldRow(icon: "house", placeholder: "Address line 2 (optional)",
                                 text: $address.line2, contentType: .streetAddressLine2)
                        FieldRow(icon: "building.2.fill", placeholder: "City",
                                 text: $address.city, contentType: .addressCity)
                        FieldRow(icon: "number", placeholder: "Postcode",
                                 text: $address.postcode, contentType: .postalCode)
                        FieldRow(icon: "globe.europe.africa.fill", placeholder: "Country",
                                 text: $address.country, contentType: .countryName)
                    }
                    .padding(.horizontal, 28)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Using")
                            .font(AppTheme.sans(11, weight: .bold))
                            .tracking(1.4)
                            .foregroundColor(AppTheme.stone)
                        Text(privateAddress.oneLine)
                            .font(AppTheme.sans(14, weight: .medium))
                            .foregroundColor(AppTheme.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(AppTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 28)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer().frame(height: 60)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }
}

// MARK: - Step 5: Phone

struct PhoneStep: View {
    @Binding var phone: String
    @State private var appeared = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 40)

            VStack(alignment: .leading, spacing: 14) {
                Text("Contact\nnumber.")
                    .font(AppTheme.serif(36))
                    .lineSpacing(-2)
                    .foregroundColor(AppTheme.ink)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)

                Text("Customers will use this to reach you about bookings. Never shown publicly.")
                    .font(AppTheme.sans(15))
                    .foregroundColor(AppTheme.slate)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)

            Spacer().frame(height: 32)

            FieldRow(
                icon: "phone.fill",
                placeholder: "e.g. 07123 456789",
                text: $phone,
                contentType: .telephoneNumber,
                keyboard: .phonePad,
                submitLabel: .done
            )
            .focused($focused)
            .padding(.horizontal, 28)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                focused = true
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }
}
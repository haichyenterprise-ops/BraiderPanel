import SwiftUI

struct BraiderProfileView: View {

    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showEditPortfolio = false
    @State private var showEditServices = false
    @State private var showEditAvailability = false
    @State private var showEditSpecialties = false
    @State private var showSignOutConfirm = false
    @State private var showPreviewSheet = false

    @State private var scrollOffset: CGFloat = 0
    @State private var heroScale: CGFloat = 1
    @State private var headerOpacity: Double = 0
    @State private var activeSection: Section = .hero

    enum Section: Int, CaseIterable {
        case hero, work, about, services
    }

    private var braider: Braider? { fb.myBraider }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {

                AppTheme.ink.ignoresSafeArea()

                if fb.myBraider == nil {
                    loadingState
                } else {
                    scrollContent(width: geo.size.width, height: geo.size.height)
                }

                // Floating chrome
                topChrome
                    .opacity(headerOpacity)

                stageRail
                    .frame(maxHeight: .infinity, alignment: .center)
                    .padding(.trailing, 12)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .allowsHitTesting(false)

                editButton
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 40)

                if showEditProfile,
                   let b = fb.myBraider {
                    EditProfileSheet(braider: b)
                        .transition(.move(edge: .bottom))
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea()
        .sheet(isPresented: $showEditPortfolio) { EditPortfolioSheet() }
        .sheet(isPresented: $showSettings) { SettingsSheet() }
        .sheet(isPresented: $showEditServices) { EditServicesSheet() }
        .sheet(isPresented: $showEditAvailability) { EditAvailabilitySheet() }
        .sheet(isPresented: $showEditSpecialties) { EditSpecialtiesSheet() }
        .sheet(isPresented: $showPreviewSheet) { PreviewAsCustomerSheet() }
        .alert("Sign out?", isPresented: $showSignOutConfirm) {
            Button("Sign out", role: .destructive) { session.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to log back in to manage your profile.")
        }
        .onAppear {
            let uid = session.uid
            if !uid.isEmpty {
                Task { await fb.loadMyBraider(uid: uid) }
            }
        }
    }

    // MARK: - Scroll content

    private func scrollContent(width: CGFloat, height: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {

                heroSection(width: width, height: height)

                workSection(width: width)

                aboutSection(width: width)

                servicesSection(width: width)

                Color.clear.frame(height: 180)
            }
            .background(alignment: .top) {
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: ScrollOffsetKey.self,
                            value: -proxy.frame(in: .named("braiderProfileScroll")).minY
                        )
                }
            }
        }
        .coordinateSpace(name: "braiderProfileScroll")
        .onPreferenceChange(ScrollOffsetKey.self) { value in
            handleScroll(value, screenHeight: height)
        }
        .ignoresSafeArea()
    }

    private func handleScroll(_ offset: CGFloat, screenHeight: CGFloat) {
        scrollOffset = offset
        let progress = min(max(offset / screenHeight, 0), 1)
        heroScale = 1 + progress * 0.15
        headerOpacity = min(max((offset - 60) / 200, 0), 1)

        let normalized = offset / screenHeight
        let newSection: Section
        if normalized < 0.8 { newSection = .hero }
        else if normalized < 1.6 { newSection = .work }
        else if normalized < 2.4 { newSection = .about }
        else { newSection = .services }

        if newSection != activeSection {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                activeSection = newSection
            }
            Haptics.select()
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: 20) {
            ProgressView().tint(.white)
            Text("Loading your profile…")
                .font(AppTheme.sans(14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Top chrome

    private var topChrome: some View {
    VStack {
        HStack(spacing: 12) {
            Button {
                Haptics.soft()
                showPreviewSheet = true
            } label: {
                Image(systemName: "eye.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.snow, in: Circle())
                    .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
            }
            .buttonStyle(BouncyPress())

            VStack(alignment: .leading, spacing: 1) {
                Text(braider?.name.isEmpty == false ? (braider?.name ?? "") : "Your profile")
                    .font(AppTheme.sans(15, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle()
                        .fill(braider?.published == true ? AppTheme.success : AppTheme.warn)
                        .frame(width: 6, height: 6)
                    Text(braider?.published == true ? "Live on the map" : "Not yet published")
                        .font(AppTheme.sans(11, weight: .medium))
                        .foregroundColor(AppTheme.slate)
                }
            }

            Spacer()

            Button {
                Haptics.soft()
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.snow, in: Circle())
                    .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
            }
            .buttonStyle(BouncyPress())
        }
        .padding(.horizontal, 16)
        .padding(.top, 56)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.cloud.opacity(0.98),
                    AppTheme.cloud.opacity(0.9),
                    AppTheme.cloud.opacity(0)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )

        Spacer()
    }
}

    // MARK: - Stage rail

    private var stageRail: some View {
        VStack(spacing: 10) {
            ForEach(Section.allCases, id: \.rawValue) { section in
                Circle()
                    .fill(section == activeSection ? AppTheme.accent : Color.white.opacity(0.5))
                    .frame(
                        width: section == activeSection ? 8 : 6,
                        height: section == activeSection ? 8 : 6
                    )
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: activeSection)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
        .opacity(headerOpacity)
    }

    // MARK: - Edit button

    private var editButton: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.soft()
                showEditPortfolio = true
            } label: {
                Image(systemName: "photo.stack")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                    .frame(width: 58, height: 58)
                    .background(AppTheme.snow, in: Circle())
                    .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
            }
            .buttonStyle(BouncyPress())

            Button {
                Haptics.medium()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    showEditProfile = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Edit profile")
                        .font(AppTheme.sans(16, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                        .opacity(0.7)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(AppTheme.inkGradient)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: AppTheme.ink.opacity(0.3), radius: 18, y: 8)
            }
            .buttonStyle(SoftPress())
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 30)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.cloud.opacity(0),
                    AppTheme.cloud.opacity(0.95),
                    AppTheme.cloud
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - HERO

    private func heroSection(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {

            if let cover = braider?.coverUrl, !cover.isEmpty {
                RemoteImage(url: cover)
                    .frame(width: width, height: height)
                    .clipped()
                    .scaleEffect(heroScale)
                    .offset(y: scrollOffset > 0 ? scrollOffset * 0.4 : 0)
            } else {
                // Placeholder gradient if no cover yet
                AppTheme.inkGradient
                    .frame(width: width, height: height)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(.white.opacity(0.3))
                            Text("Add a cover photo")
                                .font(AppTheme.sans(14, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    )
            }

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.35), location: 0.0),
                    .init(color: .clear, location: 0.35),
                    .init(color: .black.opacity(0.35), location: 0.65),
                    .init(color: .black.opacity(0.95), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 20) {

                HStack {
                    Spacer()
                    publishBadge
                }
                .padding(.top, 90)

                Spacer()

                avatarAndName

                HStack(spacing: 8) {
                    GlassChip(icon: "star.fill", title: String(format: "%.1f", braider?.rating ?? 0))
                    GlassChip(icon: "mappin.and.ellipse", title: braider?.city ?? "—")
                    GlassChip(icon: "clock", title: braider?.responseTime ?? "—")
                }

                if let bio = braider?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(AppTheme.sans(14))
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(4)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Tap Edit profile to write your bio.")
                        .font(AppTheme.sans(14))
                        .foregroundColor(.white.opacity(0.55))
                        .italic()
                }

                HStack(spacing: 6) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                    Text("Scroll to manage")
                        .font(AppTheme.sans(11, weight: .semibold))
                        .tracking(0.5)
                }
                .foregroundColor(.white.opacity(0.55))
                .padding(.top, 4)
                .opacity(scrollOffset < 40 ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: scrollOffset)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 140)
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private var publishBadge: some View {
        let published = braider?.published == true
        return HStack(spacing: 6) {
            Circle()
                .fill(published ? AppTheme.success : AppTheme.warn)
                .frame(width: 6, height: 6)
                .shadow(color: published ? AppTheme.success : AppTheme.warn, radius: 4)
            Text(published ? "Published" : "Draft")
                .font(AppTheme.sans(11, weight: .bold))
                .tracking(0.5)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
    }

    private var avatarAndName: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(AppTheme.accentLight, lineWidth: 2.5)
                    .frame(width: 92, height: 92)

                if let avatar = braider?.avatarUrl, !avatar.isEmpty {
                    RemoteImage(url: avatar)
                        .frame(width: 82, height: 82)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle().fill(AppTheme.inkGradient)
                        Image(systemName: "person.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .frame(width: 82, height: 82)
                }
            }
            .shadow(color: .black.opacity(0.4), radius: 16, y: 6)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(braider?.name.isEmpty == false ? (braider?.name ?? "") : "Your name")
                        .font(AppTheme.serif(28))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                if let tagline = braider?.tagline, !tagline.isEmpty {
                    Text(tagline)
                        .font(AppTheme.sans(13, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                } else {
                    Text("Add a tagline in Edit profile")
                        .font(AppTheme.sans(12))
                        .foregroundColor(.white.opacity(0.5))
                        .italic()
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - WORK

    private func workSection(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 24) {

            sectionHeader(
                eyebrow: "PORTFOLIO",
                title: "Recent work",
                subtitle: "\(braider?.portfolio.count ?? 0) photos",
                action: {
                    Haptics.soft()
                    showEditPortfolio = true
                },
                actionLabel: "Manage"
            )
            .padding(.horizontal, 24)

            if let portfolio = braider?.portfolio, !portfolio.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(portfolio.enumerated()), id: \.element.id) { idx, item in
                            WorkCardEditable(item: item, index: idx)
                                .frame(width: 260, height: 400)
                        }

                        // "Add more" tile
                        Button {
                            Haptics.medium()
                            showEditPortfolio = true
                        } label: {
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: 60, height: 60)
                                    Image(systemName: "plus")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                Text("Add more")
                                    .font(AppTheme.sans(13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .frame(width: 260, height: 400)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .strokeBorder(
                                        Color.white.opacity(0.15),
                                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 6])
                                    )
                            )
                        }
                        .buttonStyle(CardPress())
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 4)
                }
            } else {
                emptyPortfolioCard
                    .padding(.horizontal, 24)
            }
        }
        .padding(.top, 32)
        .padding(.bottom, 40)
        .frame(width: width, alignment: .leading)
        .background(AppTheme.ink)
    }

    private var emptyPortfolioCard: some View {
        Button {
            Haptics.medium()
            showEditPortfolio = true
        } label: {
            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.06)).frame(width: 72, height: 72)
                    Image(systemName: "photo.stack")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.white.opacity(0.5))
                }
                VStack(spacing: 4) {
                    Text("Build your portfolio")
                        .font(AppTheme.sans(16, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Add photos of your best work to win bookings.")
                        .font(AppTheme.sans(12))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        Color.white.opacity(0.12),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 6])
                    )
            )
        }
        .buttonStyle(CardPress())
    }

    // MARK: - ABOUT

    private func aboutSection(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 24) {

            sectionHeader(
                eyebrow: "ABOUT",
                title: "Meet \(firstName)",
                subtitle: braider?.city ?? "—",
                action: {
                    Haptics.soft()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        showEditProfile = true
                    }
                },
                actionLabel: "Edit"
            )
            .padding(.horizontal, 24)

            // Stats
            HStack(spacing: 12) {
                statBlock(
                    value: String(format: "%.1f", braider?.rating ?? 0),
                    label: "Rating",
                    icon: "star.fill",
                    tint: AppTheme.gold
                )
                statBlock(
                    value: "\(braider?.yearsExperience ?? 0)",
                    label: "Years exp.",
                    icon: "clock.fill",
                    tint: AppTheme.accentLight
                )
                statBlock(
                    value: "\(braider?.reviewCount ?? 0)",
                    label: "Bookings",
                    icon: "calendar",
                    tint: AppTheme.sage
                )
            }
            .padding(.horizontal, 24)

            // Story card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("The story")
                        .font(AppTheme.sans(11, weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(.white.opacity(0.45))
                    Spacer()
                    Button {
                        Haptics.soft()
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            showEditProfile = true
                        }
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.accentLight)
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(BouncyPress())
                }

                if let story = braider?.story, !story.isEmpty {
                    Text(story)
                        .font(AppTheme.sans(15))
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Tell customers your story — how you started, what you love about braiding, and why they should book you.")
                        .font(AppTheme.sans(14))
                        .foregroundColor(.white.opacity(0.45))
                        .italic()
                        .lineSpacing(4)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .padding(.horizontal, 24)

            // Specialties
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Specialties")
                        .font(AppTheme.sans(11, weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(.white.opacity(0.45))
                    Spacer()
                    Button {
                        Haptics.soft()
                        showEditSpecialties = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text("Edit")
                                .font(AppTheme.sans(12, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.accentLight)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(SoftPress())
                }

                if let specs = braider?.specialties, !specs.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(specs, id: \.self) { s in
                            HStack(spacing: 6) {
                                Image(systemName: "sparkle")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(AppTheme.accentLight)
                                Text(s)
                                    .font(AppTheme.sans(13, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(Color.white.opacity(0.08), in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                        }
                    }
                } else {
                    Text("Add your specialties (e.g. Knotless, Box Braids)")
                        .font(AppTheme.sans(13))
                        .foregroundColor(.white.opacity(0.45))
                        .italic()
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 32)
        .padding(.bottom, 40)
        .frame(width: width, alignment: .leading)
        .background(AppTheme.ink)
    }

    private var firstName: String {
        guard let name = braider?.name, !name.isEmpty else { return "you" }
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    private func statBlock(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle().fill(tint.opacity(0.18)).frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(tint)
            }

            Text(value)
                .font(AppTheme.serif(30))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(label.uppercased())
                .font(AppTheme.sans(9, weight: .bold))
                .tracking(1.1)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: - SERVICES

    private func servicesSection(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 24) {

            sectionHeader(
                eyebrow: "SERVICES",
                title: "What you offer",
                subtitle: "\(braider?.services.count ?? 0) services",
                action: {
                    Haptics.soft()
                    showEditServices = true
                },
                actionLabel: "Manage"
            )
            .padding(.horizontal, 24)

            if let services = braider?.services, !services.isEmpty {
                VStack(spacing: 12) {
                    ForEach(services) { service in
                        ServiceRow(service: service) {
                            Haptics.soft()
                            showEditServices = true
                        }
                    }
                }
                .padding(.horizontal, 24)
            } else {
                emptyServicesCard
                    .padding(.horizontal, 24)
            }

            // Availability card
            Button {
                Haptics.soft()
                showEditAvailability = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(AppTheme.accentSoft).frame(width: 44, height: 44)
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.accent)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Availability")
                            .font(AppTheme.sans(15, weight: .semibold))
                            .foregroundColor(.white)
                        Text("\(braider?.availableDates.count ?? 0) dates · \(totalSlots) time slots")
                            .font(AppTheme.sans(12))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(16)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
            }
            .buttonStyle(CardPress())
            .padding(.horizontal, 24)
        }
        .padding(.top, 32)
        .padding(.bottom, 40)
        .frame(width: width, alignment: .leading)
        .background(AppTheme.ink)
    }

    private var totalSlots: Int {
        guard let slots = braider?.availableSlots else { return 0 }
        return slots.values.reduce(0) { $0 + $1.count }
    }

    private var emptyServicesCard: some View {
        Button {
            Haptics.medium()
            showEditServices = true
        } label: {
            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.06)).frame(width: 72, height: 72)
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.white.opacity(0.5))
                }
                VStack(spacing: 4) {
                    Text("Add your first service")
                        .font(AppTheme.sans(16, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Add at least one service to go live on the customer map.")
                        .font(AppTheme.sans(12))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        Color.white.opacity(0.12),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 6])
                    )
            )
        }
        .buttonStyle(CardPress())
    }

    // MARK: - Section header

    private func sectionHeader(
        eyebrow: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void,
        actionLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(eyebrow)
                    .font(AppTheme.sans(10, weight: .bold))
                    .tracking(2.0)
                    .foregroundColor(AppTheme.accentLight)
                Spacer()

                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionLabel)
                            .font(AppTheme.sans(12, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(SoftPress())
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(AppTheme.serif(26))
                    .foregroundColor(.white)

                Text("·")
                    .font(AppTheme.sans(20))
                    .foregroundColor(.white.opacity(0.3))

                Text(subtitle)
                    .font(AppTheme.sans(13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Scroll offset key

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Editable work card

struct WorkCardEditable: View {
    let item: PortfolioItem
    let index: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: item.imageUrl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.6), .black.opacity(0.95)],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Text("#\(index + 1)")
                        .font(AppTheme.sans(10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))

                    if !item.tag.isEmpty {
                        Text(item.tag.uppercased())
                            .font(AppTheme.sans(10, weight: .bold))
                            .tracking(1.2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                    }

                    Spacer()
                }

                if !item.caption.isEmpty {
                    Text(item.caption)
                        .font(AppTheme.serif(17, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
    }
}

// MARK: - Service row

struct ServiceRow: View {
    let service: BraidService
    let onTap: () -> Void

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
                        Text(service.name.isEmpty ? "Untitled service" : service.name)
                            .font(AppTheme.sans(15, weight: .semibold))
                            .foregroundColor(.white)
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
                            .foregroundColor(AppTheme.accentLight)
                        Text("·")
                            .foregroundColor(.white.opacity(0.3))
                        Text("\(service.durationMinutes / 60)h \(service.durationMinutes % 60)m")
                            .font(AppTheme.sans(12))
                            .foregroundColor(.white.opacity(0.55))
                    }

                    if !service.description.isEmpty {
                        Text(service.description)
                            .font(AppTheme.sans(11))
                            .foregroundColor(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(CardPress())
    }
}

// MARK: - Preview sheet

struct PreviewAsCustomerSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.cloud.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 40))
                            .foregroundColor(AppTheme.accent)
                            .padding(.top, 40)

                        Text("This is how customers see you")
                            .font(AppTheme.serif(24))
                            .foregroundColor(AppTheme.ink)
                            .multilineTextAlignment(.center)

                        Text("Open the BraidMe app on the customer side and look for yourself on the Birmingham map. Your pin will show your profile picture.")
                            .font(AppTheme.sans(14))
                            .foregroundColor(AppTheme.slate)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 30)

                        Divider().padding(.vertical, 20)

                        VStack(alignment: .leading, spacing: 10) {
                            previewRow(
                                done: FirebaseManager.shared.myBraider?.published == true,
                                text: "At least one service added"
                            )
                            previewRow(
                                done: (FirebaseManager.shared.myBraider?.portfolio.count ?? 0) > 0,
                                text: "Portfolio has photos"
                            )
                            previewRow(
                                done: !(FirebaseManager.shared.myBraider?.avatarUrl.isEmpty ?? true),
                                text: "Profile picture set"
                            )
                            previewRow(
                                done: !(FirebaseManager.shared.myBraider?.bio.isEmpty ?? true),
                                text: "Bio written"
                            )
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 10)

                        Spacer()
                    }
                }
            }
            .navigationTitle("Customer Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(AppTheme.sans(15, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                }
            }
        }
    }

    private func previewRow(done: Bool, text: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(done ? AppTheme.success.opacity(0.15) : AppTheme.mist)
                    .frame(width: 26, height: 26)
                Image(systemName: done ? "checkmark" : "minus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(done ? AppTheme.success : AppTheme.stone)
            }
            Text(text)
                .font(AppTheme.sans(14, weight: .medium))
                .foregroundColor(done ? AppTheme.ink : AppTheme.slate)
            Spacer()
        }
    }
}
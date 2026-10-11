import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()

    private let dbRef = Firestore.firestore()
    var db: Firestore { dbRef }

    @Published var myBraider: Braider?
    @Published var isLoading = false
    @Published var lastError: String?

    private init() {}

    // MARK: - Braider doc

    func loadMyBraider(uid: String) async {
        guard !uid.isEmpty else { return }
        isLoading = true
        do {
            let snap = try await dbRef.collection("braiders").document(uid).getDocument()
            if let data = snap.data() {
                self.myBraider = BraiderMapper.from(id: uid, data: data)
            } else {
                self.myBraider = nil
            }
        } catch {
            lastError = error.localizedDescription
            print("[FirebaseManager] loadMyBraider failed:", error)
        }
        isLoading = false
    }

    /// Called at the end of onboarding — creates the doc with initial values.
    func createBraiderDoc(_ braider: Braider) async throws {
        try await dbRef.collection("braiders").document(braider.id).setData(braider.dictionary, merge: true)
        self.myBraider = braider
    }

    /// Generic partial update — merges into the existing braider doc.
    func updateBraider(uid: String, data: [String: Any]) async throws {
        guard !uid.isEmpty else { return }
        var payload = data
        payload["updatedAt"] = Date()
        try await dbRef.collection("braiders").document(uid).setData(payload, merge: true)

        // Reload
        await loadMyBraider(uid: uid)
    }

    /// Full save — writes the entire Braider struct.
    func saveBraider(_ braider: Braider) async throws {
        var dict = braider.dictionary

        // Auto-derive published state: at least one service with a name + image
        let hasValidService = braider.services.contains { !$0.name.isEmpty && !$0.imageUrl.isEmpty }
        dict["published"] = hasValidService
        dict["priceFrom"] = braider.services.map { $0.priceFrom }.min() ?? 0

        try await dbRef.collection("braiders").document(braider.id).setData(dict, merge: true)
        await loadMyBraider(uid: braider.id)
    }

    // MARK: - Bookings for this braider

    func fetchBookings(forBraiderId braiderId: String) async -> [Booking] {
        guard !braiderId.isEmpty else { return [] }
        do {
            let snap = try await dbRef.collection("bookings")
                .whereField("braiderId", isEqualTo: braiderId)
                .getDocuments()

            return snap.documents.compactMap { doc -> Booking? in
                let data = doc.data()
                guard
                    let braiderName = data["braiderName"] as? String,
                    let customerName = data["customerName"] as? String ?? Optional("Customer"),
                    let ts = data["date"] as? Timestamp,
                    let time = data["time"] as? String,
                    let style = data["style"] as? String,
                    let price = data["price"] as? Int,
                    let status = data["status"] as? String,
                    let created = data["createdAt"] as? Timestamp
                else { return nil }

                return Booking(
                    id: doc.documentID,
                    braiderName: braiderName,
                    braiderId: braiderId,
                    customerName: customerName,
                    date: ts.dateValue(),
                    time: time,
                    style: style,
                    price: price,
                    status: status,
                    createdAt: created.dateValue()
                )
            }
        } catch {
            print("[FirebaseManager] fetchBookings failed:", error)
            return []
        }
    }
}

// MARK: - Mapper

enum BraiderMapper {
    static func from(id: String, data: [String: Any]) -> Braider? {
        let portfolioRaw = (data["portfolio"] as? [[String: Any]]) ?? []
        let servicesRaw = (data["services"] as? [[String: Any]]) ?? []
        let slotsRaw = (data["availableSlots"] as? [String: [String]]) ?? [:]

        let datesRaw: [Date] = {
            if let dates = data["availableDates"] as? [Date] { return dates }
            if let stamps = data["availableDates"] as? [Timestamp] {
                return stamps.map { $0.dateValue() }
            }
            return []
        }()

        let portfolio: [PortfolioItem] = portfolioRaw.compactMap { p in
            guard let pid = p["id"] as? String,
                  let url = p["imageUrl"] as? String else { return nil }
            return PortfolioItem(
                id: pid,
                imageUrl: url,
                caption: (p["caption"] as? String) ?? "",
                tag: (p["tag"] as? String) ?? "",
                likes: (p["likes"] as? Int) ?? 0
            )
        }

        let services: [BraidService] = servicesRaw.compactMap { s -> BraidService? in
    guard let sid = s["id"] as? String,
          let name = s["name"] as? String else { return nil }

    let serviceDates: [Date] = {
        if let d = s["availableDates"] as? [Date] { return d }
        if let ts = s["availableDates"] as? [Timestamp] {
            return ts.map { $0.dateValue() }
        }
        return []
    }()

    let serviceSlots = (s["availableSlots"] as? [String: [String]]) ?? [:]

    return BraidService(
        id: sid,
        name: name,
        description: (s["description"] as? String) ?? "",
        imageUrl: (s["imageUrl"] as? String) ?? "",
        priceFrom: (s["priceFrom"] as? Int) ?? 0,
        durationMinutes: (s["durationMinutes"] as? Int) ?? 120,
        includes: (s["includes"] as? [String]) ?? [],
        popular: (s["popular"] as? Bool) ?? false,
        availableDates: serviceDates,
        availableSlots: serviceSlots
    )
}

        let privateAddr = AddressMapper.from(data["privateAddress"] as? [String: Any])
        let businessAddr = AddressMapper.from(data["businessAddress"] as? [String: Any])

        let dob: Date? = {
            if let d = data["dateOfBirth"] as? Date { return d }
            if let t = data["dateOfBirth"] as? Timestamp { return t.dateValue() }
            return nil
        }()

        return Braider(
            id: id,
            name: (data["name"] as? String) ?? "",
            tagline: (data["tagline"] as? String) ?? "",
            avatarUrl: (data["avatarUrl"] as? String) ?? "",
            coverUrl: (data["coverUrl"] as? String) ?? "",
            latitude: (data["latitude"] as? Double) ?? 52.4862,
            longitude: (data["longitude"] as? Double) ?? -1.8904,
            rating: (data["rating"] as? Double) ?? 0,
            reviewCount: (data["reviewCount"] as? Int) ?? 0,
            priceFrom: (data["priceFrom"] as? Int) ?? 0,
            bio: (data["bio"] as? String) ?? "",
            story: (data["story"] as? String) ?? "",
            city: (data["city"] as? String) ?? "Birmingham",
            specialties: (data["specialties"] as? [String]) ?? [],
            yearsExperience: (data["yearsExperience"] as? Int) ?? 0,
            responseTime: (data["responseTime"] as? String) ?? "~30 min",
            verified: (data["verified"] as? Bool) ?? false,
            onboarded: (data["onboarded"] as? Bool) ?? false,
            published: (data["published"] as? Bool) ?? false,
            phone: (data["phone"] as? String) ?? "",
            email: (data["email"] as? String) ?? "",
            dateOfBirth: dob,
            privateAddress: privateAddr,
            businessAddress: businessAddr,
            portfolio: portfolio,
            services: services,
            availableSlots: slotsRaw,
            availableDates: datesRaw
        )
    }
}

enum AddressMapper {
    static func from(_ raw: [String: Any]?) -> Address {
        guard let raw else { return .empty }
        return Address(
            line1: (raw["line1"] as? String) ?? "",
            line2: (raw["line2"] as? String) ?? "",
            city: (raw["city"] as? String) ?? "",
            postcode: (raw["postcode"] as? String) ?? "",
            country: (raw["country"] as? String) ?? "United Kingdom"
        )
    }
}
import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseDatabase

@MainActor
final class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()

    private let dbRef = Firestore.firestore()
    private let rtdb = Database.database().reference()

    var db: Firestore { dbRef }
    var rtdbRoot: DatabaseReference { rtdb }

    @Published var myBraider: Braider?
    @Published var bookings: [Booking] = []
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

    func createBraiderDoc(_ braider: Braider) async throws {
        try await dbRef.collection("braiders").document(braider.id).setData(braider.dictionary, merge: true)
        self.myBraider = braider
    }

    func updateBraider(uid: String, data: [String: Any]) async throws {
        guard !uid.isEmpty else { return }
        var payload = data
        payload["updatedAt"] = Date()
        try await dbRef.collection("braiders").document(uid).setData(payload, merge: true)
        await loadMyBraider(uid: uid)
    }

    func saveBraider(_ braider: Braider) async throws {
        var dict = braider.dictionary
        let hasValidService = braider.services.contains { !$0.name.isEmpty && !$0.imageUrl.isEmpty }
        dict["published"] = hasValidService
        dict["priceFrom"] = braider.services.map { $0.priceFrom }.filter { $0 > 0 }.min() ?? 0
        try await dbRef.collection("braiders").document(braider.id).setData(dict, merge: true)
        await loadMyBraider(uid: braider.id)
    }

    // MARK: - Bookings

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
                    customerName: (data["customerName"] as? String) ?? (data["uid"] as? String).map { "Customer \($0.prefix(6))" } ?? "Customer",
                    date: ts.dateValue(),
                    time: time,
                    style: style,
                    price: price,
                    status: status,
                    createdAt: created.dateValue(),
                    cancellationReason: data["cancellationReason"] as? String,
                    cancellationRequestedAt: (data["cancellationRequestedAt"] as? Timestamp)?.dateValue()
                )
            }
        } catch {
            print("[FirebaseManager] fetchBookings failed:", error)
            return []
        }
    }

    // MARK: - Cancellation approval

    func approveCancellation(bookingId: String) async throws {
        try await dbRef.collection("bookings").document(bookingId).setData([
            "status": "cancelled",
            "cancelledAt": Date(),
            "approvedBy": "braider"
        ], merge: true)

        if let idx = bookings.firstIndex(where: { $0.id == bookingId }) {
            let b = bookings[idx]
            bookings[idx] = Booking(
                id: b.id, braiderName: b.braiderName, braiderId: b.braiderId,
                customerName: b.customerName,
                date: b.date, time: b.time, style: b.style,
                price: b.price, status: "cancelled", createdAt: b.createdAt,
                cancellationReason: b.cancellationReason,
                cancellationRequestedAt: b.cancellationRequestedAt
            )
        }
    }

    func denyCancellation(bookingId: String) async throws {
        try await dbRef.collection("bookings").document(bookingId).setData([
            "status": "cancellation_denied",
            "deniedAt": Date(),
            "approvedBy": "braider"
        ], merge: true)

        if let idx = bookings.firstIndex(where: { $0.id == bookingId }) {
            let b = bookings[idx]
            bookings[idx] = Booking(
                id: b.id, braiderName: b.braiderName, braiderId: b.braiderId,
                customerName: b.customerName,
                date: b.date, time: b.time, style: b.style,
                price: b.price, status: "cancellation_denied", createdAt: b.createdAt,
                cancellationReason: b.cancellationReason,
                cancellationRequestedAt: b.cancellationRequestedAt
            )
        }
    }

    // MARK: - Chat (Realtime Database)

    static func chatId(for bookingId: String) -> String {
        return "chat_\(bookingId)"
    }

    func sendMessage(
        chatId: String,
        senderId: String,
        senderName: String,
        text: String
    ) async throws {
        let ref = rtdb.child("chats").child(chatId).child("messages").childByAutoId()
        try await ref.setValue([
            "senderId": senderId,
            "senderName": senderName,
            "text": text,
            "timestamp": ServerValue.timestamp()
        ])

        try await rtdb.child("chats").child(chatId).child("meta").updateChildValues([
            "lastMessage": text,
            "lastSenderId": senderId,
            "lastUpdated": ServerValue.timestamp()
        ])
    }

    func observeMessages(
        chatId: String,
        onUpdate: @escaping ([ChatMessage]) -> Void
    ) -> DatabaseHandle {
        let ref = rtdb.child("chats").child(chatId).child("messages")
        return ref.observe(.value) { snapshot in
            var messages: [ChatMessage] = []
            for child in snapshot.children {
                guard let snap = child as? DataSnapshot,
                      let dict = snap.value as? [String: Any] else { continue }
                let senderId = (dict["senderId"] as? String) ?? ""
                let senderName = (dict["senderName"] as? String) ?? ""
                let text = (dict["text"] as? String) ?? ""
                let tsRaw = (dict["timestamp"] as? NSNumber)?.doubleValue ?? 0
                let timestamp = Date(timeIntervalSince1970: tsRaw / 1000.0)

                messages.append(ChatMessage(
                    id: snap.key,
                    senderId: senderId,
                    senderName: senderName,
                    text: text,
                    timestamp: timestamp
                ))
            }
            messages.sort { $0.timestamp < $1.timestamp }
            DispatchQueue.main.async { onUpdate(messages) }
        }
    }

    func removeObserver(chatId: String, handle: DatabaseHandle) {
        rtdb.child("chats").child(chatId).child("messages").removeObserver(withHandle: handle)
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
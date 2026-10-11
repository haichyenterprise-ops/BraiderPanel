import Foundation
import CoreLocation

// MARK: - Braider

struct Braider: Identifiable, Hashable {
    let id: String
    var name: String
    var tagline: String
    var avatarUrl: String
    var coverUrl: String
    var latitude: Double
    var longitude: Double
    var rating: Double
    var reviewCount: Int
    var priceFrom: Int
    var bio: String
    var story: String
    var city: String
    var specialties: [String]
    var yearsExperience: Int
    var responseTime: String
    var verified: Bool
    var onboarded: Bool
    var published: Bool
    var phone: String
    var email: String
    var dateOfBirth: Date?
    var privateAddress: Address
    var businessAddress: Address
    var portfolio: [PortfolioItem]
    var services: [BraidService]
    var availableSlots: [String: [String]]
    var availableDates: [Date]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func == (lhs: Braider, rhs: Braider) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static func draft(uid: String, email: String) -> Braider {
        Braider(
            id: uid, name: "", tagline: "", avatarUrl: "", coverUrl: "",
            latitude: 52.4862, longitude: -1.8904,
            rating: 0, reviewCount: 0, priceFrom: 0,
            bio: "", story: "", city: "Birmingham",
            specialties: [], yearsExperience: 0, responseTime: "~30 min",
            verified: false, onboarded: false, published: false,
            phone: "", email: email, dateOfBirth: nil,
            privateAddress: .empty, businessAddress: .empty,
            portfolio: [], services: [],
            availableSlots: [:], availableDates: []
        )
    }

    var dictionary: [String: Any] {
        var d: [String: Any] = [
            "id": id, "name": name, "tagline": tagline,
            "avatarUrl": avatarUrl, "coverUrl": coverUrl,
            "latitude": latitude, "longitude": longitude,
            "rating": rating, "reviewCount": reviewCount,
            "priceFrom": priceFrom, "bio": bio, "story": story,
            "city": city, "specialties": specialties,
            "yearsExperience": yearsExperience,
            "responseTime": responseTime,
            "verified": verified, "onboarded": onboarded, "published": published,
            "phone": phone, "email": email,
            "privateAddress": privateAddress.dictionary,
            "businessAddress": businessAddress.dictionary,
            "portfolio": portfolio.map { $0.dictionary },
            "services": services.map { $0.dictionary },
            "availableSlots": availableSlots,
            "availableDates": availableDates,
            "updatedAt": Date()
        ]
        if let dob = dateOfBirth { d["dateOfBirth"] = dob }
        return d
    }
}

// MARK: - Address

struct Address: Hashable, Codable {
    var line1: String
    var line2: String
    var city: String
    var postcode: String
    var country: String

    static let empty = Address(line1: "", line2: "", city: "", postcode: "", country: "United Kingdom")

    var dictionary: [String: Any] {
        ["line1": line1, "line2": line2, "city": city, "postcode": postcode, "country": country]
    }

    var oneLine: String {
        [line1, line2, city, postcode].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

// MARK: - Portfolio

struct PortfolioItem: Identifiable, Hashable {
    let id: String
    var imageUrl: String
    var caption: String
    var tag: String
    var likes: Int

    var dictionary: [String: Any] {
        ["id": id, "imageUrl": imageUrl, "caption": caption, "tag": tag, "likes": likes]
    }

    static func empty() -> PortfolioItem {
        PortfolioItem(id: UUID().uuidString, imageUrl: "", caption: "", tag: "", likes: 0)
    }
}

// MARK: - Service

struct BraidService: Identifiable, Hashable {
    let id: String
    var name: String
    var description: String
    var imageUrl: String
    var priceFrom: Int
    var durationMinutes: Int
    var includes: [String]
    var popular: Bool
    var availableDates: [Date]
    var availableSlots: [String: [String]]

    var dictionary: [String: Any] {
        [
            "id": id,
            "name": name,
            "description": description,
            "imageUrl": imageUrl,
            "priceFrom": priceFrom,
            "durationMinutes": durationMinutes,
            "includes": includes,
            "popular": popular,
            "availableDates": availableDates,
            "availableSlots": availableSlots
        ]
    }

    static func empty() -> BraidService {
        BraidService(
            id: UUID().uuidString,
            name: "", description: "", imageUrl: "",
            priceFrom: 0, durationMinutes: 120,
            includes: [], popular: false,
            availableDates: [], availableSlots: [:]
        )
    }

    var hasAvailability: Bool {
        !availableDates.isEmpty && availableSlots.values.contains { !$0.isEmpty }
    }
}

// MARK: - Reviews

struct Review: Identifiable, Hashable {
    let id: String
    let userId: String
    let userName: String
    let userAvatar: String
    let text: String
    let rating: Double
    let date: Date
    let styleDone: String
    let helpful: Int

    var dateString: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }
}

struct RatingBreakdown: Hashable {
    let five: Int
    let four: Int
    let three: Int
    let two: Int
    let one: Int

    var total: Int { five + four + three + two + one }

    var average: Double {
        guard total > 0 else { return 0 }
        let sum = 5 * five + 4 * four + 3 * three + 2 * two + 1 * one
        return Double(sum) / Double(total)
    }

    static let empty = RatingBreakdown(five: 0, four: 0, three: 0, two: 0, one: 0)

    static func from(_ reviews: [Review]) -> RatingBreakdown {
        var f = 0, fo = 0, t = 0, tw = 0, o = 0
        for r in reviews {
            switch Int(r.rating.rounded()) {
            case 5: f += 1
            case 4: fo += 1
            case 3: t += 1
            case 2: tw += 1
            default: o += 1
            }
        }
        return RatingBreakdown(five: f, four: fo, three: t, two: tw, one: o)
    }
}

// MARK: - Booking

struct Booking: Identifiable, Codable {
    let id: String
    let braiderName: String
    let braiderId: String
    let customerName: String
    let date: Date
    let time: String
    let style: String
    let price: Int
    let status: String
    let createdAt: Date
    let cancellationReason: String?
    let cancellationRequestedAt: Date?
}

// MARK: - Chat

struct ChatMessage: Identifiable, Hashable {
    let id: String
    let senderId: String
    let senderName: String
    let text: String
    let timestamp: Date
}
import Foundation
import CoreLocation

// MARK: - Braider (Firestore doc at braiders/{uid})

struct Braider: Identifiable, Hashable {
    let id: String                       // Firebase Auth UID
    var name: String
    var tagline: String
    var avatarUrl: String                // profile picture
    var coverUrl: String                 // hero image
    var latitude: Double
    var longitude: Double
    var rating: Double
    var reviewCount: Int
    var priceFrom: Int
    var bio: String                      // short — shown on hero
    var story: String                    // long — shown in About
    var city: String
    var specialties: [String]
    var yearsExperience: Int
    var responseTime: String
    var verified: Bool
    var onboarded: Bool
    var published: Bool                  // true once at least 1 service exists
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

    /// Empty draft used during onboarding
    static func draft(uid: String, email: String) -> Braider {
        Braider(
            id: uid,
            name: "",
            tagline: "",
            avatarUrl: "",
            coverUrl: "",
            latitude: 52.4862,
            longitude: -1.8904,
            rating: 0,
            reviewCount: 0,
            priceFrom: 0,
            bio: "",
            story: "",
            city: "Birmingham",
            specialties: [],
            yearsExperience: 0,
            responseTime: "~30 min",
            verified: false,
            onboarded: false,
            published: false,
            phone: "",
            email: email,
            dateOfBirth: nil,
            privateAddress: .empty,
            businessAddress: .empty,
            portfolio: [],
            services: [],
            availableSlots: [:],
            availableDates: []
        )
    }

    /// Dictionary for Firestore write
    var dictionary: [String: Any] {
        var d: [String: Any] = [
            "id": id,
            "name": name,
            "tagline": tagline,
            "avatarUrl": avatarUrl,
            "coverUrl": coverUrl,
            "latitude": latitude,
            "longitude": longitude,
            "rating": rating,
            "reviewCount": reviewCount,
            "priceFrom": priceFrom,
            "bio": bio,
            "story": story,
            "city": city,
            "specialties": specialties,
            "yearsExperience": yearsExperience,
            "responseTime": responseTime,
            "verified": verified,
            "onboarded": onboarded,
            "published": published,
            "phone": phone,
            "email": email,
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
        [
            "line1": line1,
            "line2": line2,
            "city": city,
            "postcode": postcode,
            "country": country
        ]
    }

    var oneLine: String {
        [line1, line2, city, postcode]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
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
        [
            "id": id,
            "imageUrl": imageUrl,
            "caption": caption,
            "tag": tag,
            "likes": likes
        ]
    }

    static func empty() -> PortfolioItem {
        PortfolioItem(
            id: UUID().uuidString,
            imageUrl: "",
            caption: "",
            tag: "",
            likes: 0
        )
    }
}

// MARK: - Service (formerly BraidStyle)

struct BraidService: Identifiable, Hashable {
    let id: String
    var name: String
    var description: String
    var imageUrl: String
    var priceFrom: Int
    var durationMinutes: Int
    var includes: [String]
    var popular: Bool

    var dictionary: [String: Any] {
        [
            "id": id,
            "name": name,
            "description": description,
            "imageUrl": imageUrl,
            "priceFrom": priceFrom,
            "durationMinutes": durationMinutes,
            "includes": includes,
            "popular": popular
        ]
    }

    static func empty() -> BraidService {
        BraidService(
            id: UUID().uuidString,
            name: "",
            description: "",
            imageUrl: "",
            priceFrom: 0,
            durationMinutes: 120,
            includes: [],
            popular: false
        )
    }
}

// MARK: - Review (read-only in this app, but needed for the profile view)

struct Review: Identifiable, Hashable {
    let id: String
    let userName: String
    let userAvatar: String
    let text: String
    let rating: Double
    let date: String
    let styleDone: String
    let helpful: Int
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
}

// MARK: - Booking (braider sees these)

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
}
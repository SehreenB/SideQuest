import Foundation
import CoreLocation

// MARK: - Enums

enum NavigatorMode: String, CaseIterable, Identifiable, Codable {
    case adventure = "Adventure"
    case foodie = "Foodie"
    case nature = "Nature"
    case culture = "Culture"
    case social = "Social"
    case mystery = "Mystery"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .adventure: return "paintbrush"
        case .foodie: return "cup.and.saucer"
        case .nature: return "leaf"
        case .culture: return "book"
        case .social: return "person.2"
        case .mystery: return "theatermasks"
        }
    }

    var subtitle: String {
        switch self {
        case .adventure: return "Murals, street art, views"
        case .foodie: return "Cafes, dessert, markets"
        case .nature: return "Parks, waterfront, trees"
        case .culture: return "Bookstores, galleries, history"
        case .social: return "Patios, lively areas"
        case .mystery: return "Random high-rated gems"
        }
    }
}

enum TravelType: String, CaseIterable, Identifiable, Codable {
    case walking = "Walking"
    case driving = "Driving"

    var id: String { rawValue }
}

enum DetourLevel: String, CaseIterable, Identifiable, Codable {
    case light = "Light"
    case moderate = "Moderate"
    case bold = "Bold"

    var id: String { rawValue }
}

enum SpotCategory: String, Codable {
    case mural, cafe, park, viewpoint, bookstore, gallery, market, patio, restaurant
}

enum MemoryVisibility: String, CaseIterable, Identifiable, Codable {
    case `private` = "Private"
    case friends = "Friends"
    case `public` = "Public"

    var id: String { rawValue }
}

enum BadgeID: String, CaseIterable, Identifiable, Codable {
    case muralHunter = "Mural Hunter"
    case parkHopper = "Park Hopper"
    case cafeCrawler = "Cafe Crawler"
    case hiddenGemFinder = "Hidden Gem Finder"
    case neighborhoodNomad = "Neighborhood Nomad"
    case communityCurator = "Community Curator"
    case streakWalker = "Streak Walker"
    case routeRookie = "Route Rookie"
    case memoryArchivist = "Memory Archivist"
    case publicIcon = "Public Icon"
    case pointsPioneer = "Points Pioneer"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .muralHunter: return "Visit 5 murals"
        case .parkHopper: return "Visit 5 parks"
        case .cafeCrawler: return "Visit 5 cafes"
        case .hiddenGemFinder: return "Complete a Find It challenge"
        case .neighborhoodNomad: return "Explore 3 neighborhoods"
        case .communityCurator: return "Share 3 public memories"
        case .streakWalker: return "7-day streak"
        case .routeRookie: return "Complete your first route"
        case .memoryArchivist: return "Capture 10 memories"
        case .publicIcon: return "Share 8 public memories"
        case .pointsPioneer: return "Reach 1000 total points"
        }
    }
}

// MARK: - Data Structures

struct UserProfile {
    var id: UUID
    var displayName: String
    var points: Int
    var streak: Int
    var routesCompleted: Int
    var unlockedBadges: Set<BadgeID>
    var defaultPublicPosting: Bool
}

struct Spot: Identifiable {
    let id: UUID
    let name: String
    let category: SpotCategory
    let shortDescription: String
    let coordinate: CLLocationCoordinate2D
    let modeTags: [NavigatorMode]
    let travelTags: [TravelType]
    let googlePlaceID: String?

    init(
        id: UUID,
        name: String,
        category: SpotCategory,
        shortDescription: String,
        coordinate: CLLocationCoordinate2D,
        modeTags: [NavigatorMode],
        travelTags: [TravelType],
        googlePlaceID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.shortDescription = shortDescription
        self.coordinate = coordinate
        self.modeTags = modeTags
        self.travelTags = travelTags
        self.googlePlaceID = googlePlaceID
    }
}

struct NavigationInstruction: Identifiable {
    let id: UUID
    let text: String
    let distanceMeters: Int
    let durationSeconds: Int
    let coordinate: CLLocationCoordinate2D

    init(
        id: UUID = UUID(),
        text: String,
        distanceMeters: Int,
        durationSeconds: Int,
        coordinate: CLLocationCoordinate2D
    ) {
        self.id = id
        self.text = text
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.coordinate = coordinate
    }
}

struct RoutePlan: Identifiable {
    let id: UUID
    let mode: NavigatorMode
    let travelType: TravelType
    let detour: DetourLevel
    let stopCount: Int
    let destinationName: String?
    let stops: [Spot]
    let estimatedMinutes: Int
    let detourAddedMinutes: Int
    let estimatedPoints: Int
    let whyThisRoute: String
    let routePolyline: [CLLocationCoordinate2D]
    let fastestMinutes: Int
    let navigationInstructions: [NavigationInstruction]

    init(
        id: UUID,
        mode: NavigatorMode,
        travelType: TravelType,
        detour: DetourLevel,
        stopCount: Int,
        destinationName: String?,
        stops: [Spot],
        estimatedMinutes: Int,
        detourAddedMinutes: Int,
        estimatedPoints: Int,
        whyThisRoute: String,
        routePolyline: [CLLocationCoordinate2D] = [],
        fastestMinutes: Int = 0,
        navigationInstructions: [NavigationInstruction] = []
    ) {
        self.id = id
        self.mode = mode
        self.travelType = travelType
        self.detour = detour
        self.stopCount = stopCount
        self.destinationName = destinationName
        self.stops = stops
        self.estimatedMinutes = estimatedMinutes
        self.detourAddedMinutes = detourAddedMinutes
        self.estimatedPoints = estimatedPoints
        self.whyThisRoute = whyThisRoute
        self.routePolyline = routePolyline
        self.fastestMinutes = fastestMinutes
        self.navigationInstructions = navigationInstructions
    }
}

struct MemoryItem: Identifiable {
    let id: UUID
    let userId: UUID
    let spotId: UUID
    var caption: String
    var tags: [String]
    var visibility: MemoryVisibility
    let createdAt: Date
    let googlePlaceID: String?

    init(
        id: UUID,
        userId: UUID,
        spotId: UUID,
        caption: String,
        tags: [String],
        visibility: MemoryVisibility,
        createdAt: Date,
        googlePlaceID: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.spotId = spotId
        self.caption = caption
        self.tags = tags
        self.visibility = visibility
        self.createdAt = createdAt
        self.googlePlaceID = googlePlaceID
    }
}

struct Challenge: Identifiable {
    let id: UUID
    let title: String
    let clueTitles: [String]
    let difficulty: String
    let rewardPoints: Int
    let targetSpot: Spot
}

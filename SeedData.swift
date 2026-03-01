import Foundation
import CoreLocation

enum SeedData {
    static let spots: [Spot] = {
        // Toronto-ish coords (you can change later)
        let base = CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)

        func jitter(_ lat: Double, _ lon: Double) -> CLLocationCoordinate2D {
            .init(latitude: base.latitude + lat, longitude: base.longitude + lon)
        }

        return [
            Spot(id: UUID(), name: "Graffiti Alley", category: .mural,
                 shortDescription: "A long alley packed with vibrant street art.",
                 coordinate: jitter(0.003, -0.010),
                 modeTags: [.adventure, .culture], travelTags: [.walking]),

            Spot(id: UUID(), name: "Hidden Espresso Bar", category: .cafe,
                 shortDescription: "Tiny café with a cozy interior and pastry counter.",
                 coordinate: jitter(0.006, -0.006),
                 modeTags: [.foodie, .social], travelTags: [.walking, .driving]),

            Spot(id: UUID(), name: "Waterfront Walk", category: .park,
                 shortDescription: "Open air, skyline views, and calm paths.",
                 coordinate: jitter(-0.004, -0.002),
                 modeTags: [.nature, .social], travelTags: [.walking]),

            Spot(id: UUID(), name: "Skyline Viewpoint", category: .viewpoint,
                 shortDescription: "A scenic spot to pause and take a photo.",
                 coordinate: jitter(-0.006, 0.004),
                 modeTags: [.adventure, .nature], travelTags: [.driving, .walking]),

            Spot(id: UUID(), name: "Indie Bookstore", category: .bookstore,
                 shortDescription: "Quiet corner with rare finds and a reading nook.",
                 coordinate: jitter(0.002, 0.008),
                 modeTags: [.culture], travelTags: [.walking, .driving]),
        ]
    }()

    static func sampleChallenges() -> [Challenge] {
        guard let target = spots.first else { return [] }
        return [
            Challenge(
                id: UUID(),
                title: "Find It: The Painted Alley",
                clueTitles: ["A wall of color", "A narrow passage", "Look for bold letters"],
                difficulty: "Medium",
                rewardPoints: 250,
                targetSpot: target
            )
        ]
    }

    static func buildRoute(mode: NavigatorMode, travel: TravelType, detour: DetourLevel, stopCount: Int, destination: String?) -> RoutePlan {
        let filtered = spots.filter { $0.modeTags.contains(mode) && $0.travelTags.contains(travel) }
        let picked = Array(filtered.prefix(stopCount)).isEmpty ? Array(spots.prefix(stopCount)) : Array(filtered.prefix(stopCount))

        let detourAdded: Int = (detour == .light ? 3 : detour == .moderate ? 6 : 10)
        let baseTime: Int = (travel == .walking ? 12 : 18)
        let estPoints: Int = 150 + (stopCount * 60) + (detour == .bold ? 80 : 0)

        return RoutePlan(
            id: UUID(),
            mode: mode,
            travelType: travel,
            detour: detour,
            stopCount: stopCount,
            destinationName: destination,
            stops: picked,
            estimatedMinutes: baseTime + detourAdded,
            detourAddedMinutes: detourAdded,
            estimatedPoints: estPoints,
            whyThisRoute: "A slightly longer route that prioritizes \(mode.rawValue.lowercased()) stops you’ll actually remember."
        )
    }
}//
//  SeedData.swift
//  SideQuest
//
//  Created by betul cetintas on 2026-02-28.
//


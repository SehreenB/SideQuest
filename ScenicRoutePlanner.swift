import Foundation
import CoreLocation
import MapKit

final class ScenicRoutePlanner {
    static let shared = ScenicRoutePlanner()

    struct DestinationCandidate: Identifiable {
        let id = UUID()
        let name: String
        let subtitle: String
        let coordinate: CLLocationCoordinate2D
        let placeID: String?
    }

    func destinationCandidates(
        near origin: CLLocationCoordinate2D,
        mode: NavigatorMode,
        limit: Int = 8,
        radiusMeters: Int = 5_000
    ) async -> [DestinationCandidate] {
        var candidates: [DestinationCandidate] = []

        if let googleCandidates = try? await googleDestinationCandidates(
            near: origin,
            mode: mode,
            limit: limit * 2,
            radiusMeters: radiusMeters
        ) {
            candidates.append(contentsOf: googleCandidates)
        }

        if candidates.count < limit,
           let mapKitCandidates = try? await mapKitDestinationCandidates(
            near: origin,
            mode: mode,
            limit: limit * 2,
            radiusMeters: radiusMeters
           ) {
            candidates.append(contentsOf: mapKitCandidates)
        }

        let filtered = candidates.filter {
            distance(from: origin, to: $0.coordinate) <= Double(radiusMeters)
        }

        let deduped = deduplicated(filtered, limit: limit)
        if !deduped.isEmpty {
            return deduped
        }

        return fallbackNearbyCandidates(near: origin, mode: mode, limit: limit, radiusMeters: radiusMeters)
    }

    func generateRoute(
        mode: NavigatorMode,
        travel: TravelType,
        detour: DetourLevel,
        desiredDurationMinutes: Int,
        desiredStopCount: Int? = nil,
        origin: CLLocationCoordinate2D,
        destinationQuery: String?,
        selectedCategoryDestination: DestinationCandidate?,
        selectedSearchPlaceID: String?
    ) async throws -> RoutePlan {
        let resolvedDestination = try await resolveDestination(
            query: destinationQuery,
            selectedCategoryDestination: selectedCategoryDestination,
            selectedSearchPlaceID: selectedSearchPlaceID,
            origin: origin,
            mode: mode
        )

        let fastestEstimateMinutes = estimatedFastestMinutes(
            origin: origin,
            destination: resolvedDestination.coordinate,
            travel: travel
        )
        let extraMinutesTarget = max(0, desiredDurationMinutes - fastestEstimateMinutes)

        let desiredTotalStops = max(1, desiredStopCount ?? desiredScenicStopCount(
            desiredDurationMinutes: desiredDurationMinutes,
            travel: travel,
            detour: detour
        ))
        let desiredScenicStops = max(0, desiredTotalStops - 1)

        var scenicStops = await scenicStops(
            between: origin,
            and: resolvedDestination.coordinate,
            mode: mode,
            travel: travel,
            detour: detour,
            desiredStops: desiredScenicStops,
            desiredDurationMinutes: desiredDurationMinutes,
            extraMinutesTarget: extraMinutesTarget
        )
        scenicStops = ensureScenicStopCount(
            scenicStops,
            targetCount: desiredScenicStops,
            around: resolvedDestination.coordinate,
            mode: mode,
            travel: travel
        )

        let destinationStop = Spot(
            id: UUID(),
            name: resolvedDestination.name,
            category: .viewpoint,
            shortDescription: resolvedDestination.subtitle,
            coordinate: resolvedDestination.coordinate,
            modeTags: [mode],
            travelTags: [travel],
            googlePlaceID: resolvedDestination.placeID
        )

        let allStops = Array((scenicStops + [destinationStop]).prefix(desiredTotalStops))
        let waypoints = scenicStops.map { $0.coordinate }
        let modeString = travel == .walking ? "walking" : "driving"

        let scenicDirections = try? await GoogleMapsService.shared.getDirections(
            origin: origin,
            destination: resolvedDestination.coordinate,
            waypoints: waypoints,
            mode: modeString
        )

        let fastestDirections = try? await GoogleMapsService.shared.getDirections(
            origin: origin,
            destination: resolvedDestination.coordinate,
            mode: modeString
        )

        let legStops = [origin] + waypoints + [resolvedDestination.coordinate]
        let fallbackPolyline = await RouteBuilder.buildPolyline(
            stops: legStops,
            transport: travel == .walking ? .walking : .automobile
        )

        let scenicPolyline: [CLLocationCoordinate2D]
        if let googlePolyline = scenicDirections?.polylinePoints, googlePolyline.count > 2 {
            scenicPolyline = googlePolyline
        } else if let fallbackPolyline {
            scenicPolyline = coordinates(from: fallbackPolyline)
        } else {
            scenicPolyline = legStops
        }

        let scenicInstructions = scenicDirections?.instructions ?? []
        let scenicMinutes = max(1, (scenicDirections?.durationSeconds ?? estimatedMinutesForFallback(stops: allStops, travel: travel) * 60) / 60)
        let fastestMinutes = max(1, (fastestDirections?.durationSeconds ?? estimatedFastestMinutes(origin: origin, destination: resolvedDestination.coordinate, travel: travel) * 60) / 60)
        let detourAdded = max(0, scenicMinutes - fastestMinutes)

        let pointsBase = travel == .walking ? 170 : 130
        let points = pointsBase + (scenicStops.count * 70) + (detour == .bold ? 120 : detour == .moderate ? 70 : 30)

        return RoutePlan(
            id: UUID(),
            mode: mode,
            travelType: travel,
            detour: detour,
            stopCount: allStops.count,
            destinationName: resolvedDestination.name,
            stops: allStops,
            estimatedMinutes: scenicMinutes,
            detourAddedMinutes: detourAdded,
            estimatedPoints: points,
            whyThisRoute: "This route favors scenic roads and interesting stops while keeping your trip within your target duration.",
            routePolyline: scenicPolyline,
            fastestMinutes: fastestMinutes,
            navigationInstructions: scenicInstructions
        )
    }

    private func resolveDestination(
        query: String?,
        selectedCategoryDestination: DestinationCandidate?,
        selectedSearchPlaceID: String?,
        origin: CLLocationCoordinate2D,
        mode: NavigatorMode
    ) async throws -> DestinationCandidate {
        if let selectedCategoryDestination {
            return selectedCategoryDestination
        }

        if let selectedSearchPlaceID,
           let details = try await GoogleMapsService.shared.placeDetails(placeID: selectedSearchPlaceID) {
            return DestinationCandidate(
                name: details.name,
                subtitle: details.formattedAddress,
                coordinate: details.coordinate,
                placeID: details.placeID
            )
        }

        if let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let geocoded = try await GoogleMapsService.shared.geocode(address: query) {
                return DestinationCandidate(
                    name: geocoded.formattedAddress,
                    subtitle: "Search destination",
                    coordinate: geocoded.coordinate,
                    placeID: nil
                )
            }

            if let mapItem = try await geocodeWithMapKit(query: query) {
                return DestinationCandidate(
                    name: mapItem.name ?? query,
                    subtitle: "Search destination",
                    coordinate: mapItem.location.coordinate,
                    placeID: nil
                )
            }
        }

        if let first = await destinationCandidates(near: origin, mode: mode, limit: 1).first {
            return first
        }

        if let fallback = fallbackNearbyCandidates(near: origin, mode: mode, limit: 1, radiusMeters: 1_500).first {
            return fallback
        }

        throw GoogleMapsError.geocodingFailed
    }

    private func geocodeWithMapKit(query: String) async throws -> MKMapItem? {
        guard let request = MKGeocodingRequest(addressString: query) else {
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            request.getMapItems { mapItems, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: mapItems?.first)
            }
        }
    }

    private func googleDestinationCandidates(
        near origin: CLLocationCoordinate2D,
        mode: NavigatorMode,
        limit: Int,
        radiusMeters: Int
    ) async throws -> [DestinationCandidate] {
        let places = try await GoogleMapsService.shared.searchNearby(
            location: origin,
            radius: radiusMeters,
            type: GoogleMapsService.placesType(for: mode),
            keyword: GoogleMapsService.placesKeyword(for: mode)
        )

        return Array(places.prefix(limit)).map {
            DestinationCandidate(
                name: $0.name,
                subtitle: $0.vicinity,
                coordinate: $0.coordinate,
                placeID: $0.placeID
            )
        }
    }

    private func mapKitDestinationCandidates(
        near origin: CLLocationCoordinate2D,
        mode: NavigatorMode,
        limit: Int,
        radiusMeters: Int
    ) async throws -> [DestinationCandidate] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = mapKitQuery(for: mode)
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: origin,
            latitudinalMeters: Double(radiusMeters * 2),
            longitudinalMeters: Double(radiusMeters * 2)
        )

        let response = try await MKLocalSearch(request: request).start()
        return Array(response.mapItems.prefix(limit)).map {
            DestinationCandidate(
                name: $0.name ?? "Suggested destination",
                subtitle: "Nearby",
                coordinate: $0.location.coordinate,
                placeID: nil
            )
        }
    }

    private func scenicStops(
        between origin: CLLocationCoordinate2D,
        and destination: CLLocationCoordinate2D,
        mode: NavigatorMode,
        travel: TravelType,
        detour: DetourLevel,
        desiredStops: Int,
        desiredDurationMinutes: Int,
        extraMinutesTarget: Int
    ) async -> [Spot] {
        let directDistance = distance(from: origin, to: destination)
        let maxExtraDetourMeters = hardDetourBudgetMeters(
            for: travel,
            desiredDurationMinutes: desiredDurationMinutes,
            detour: detour,
            extraMinutesTarget: extraMinutesTarget
        )
        let maxCorridorOffset = maxCorridorOffsetMeters(for: travel, desiredDurationMinutes: desiredDurationMinutes)

        let midpoint = CLLocationCoordinate2D(
            latitude: (origin.latitude + destination.latitude) / 2,
            longitude: (origin.longitude + destination.longitude) / 2
        )

        let radiusByDuration = min(travel == .walking ? 8_000 : 20_000, max(1_200, desiredDurationMinutes * (travel == .walking ? 90 : 280)))
        let radiusByDistance = min(7000, max(1500, Int(directDistance * 0.35)))
        let radius = max(radiusByDistance, radiusByDuration)

        var picked: [Spot] = []
        if desiredStops > 0 {
            let geminiPicked = await geminiScenicStops(
                origin: origin,
                mode: mode,
                travel: travel,
                desiredStops: desiredStops,
                radiusMeters: radius
            )
            picked.append(contentsOf: geminiPicked)
        }

        let nearby = (try? await GoogleMapsService.shared.searchNearby(
            location: midpoint,
            radius: radius,
            type: GoogleMapsService.placesType(for: mode),
            keyword: GoogleMapsService.placesKeyword(for: mode)
        )) ?? []

        let scored = nearby
            .filter { distance(from: midpoint, to: $0.coordinate) <= min(Double(radius) * 1.2, maxCorridorOffset) }
            .filter {
                let via = distance(from: origin, to: $0.coordinate) + distance(from: $0.coordinate, to: destination)
                return (via - directDistance) <= maxExtraDetourMeters
            }
            .sorted { scenicScore(place: $0, origin: origin, destination: destination) < scenicScore(place: $1, origin: origin, destination: destination) }

        for place in scored {
            if picked.count >= desiredStops { break }

            if distance(from: destination, to: place.coordinate) < 120 {
                continue
            }

            if picked.contains(where: { distance(from: $0.coordinate, to: place.coordinate) < 220 }) {
                continue
            }

            picked.append(Spot(
                id: UUID(),
                name: place.name,
                category: spotCategory(from: place.types),
                shortDescription: place.vicinity,
                coordinate: place.coordinate,
                modeTags: [mode],
                travelTags: [travel],
                googlePlaceID: place.placeID
            ))
        }

        if picked.isEmpty {
            picked = fallbackScenicStops(
                around: midpoint,
                mode: mode,
                travel: travel,
                desiredStops: desiredStops,
                desiredDurationMinutes: desiredDurationMinutes
            )
        }

        let truncated = Array(picked.prefix(desiredStops))
        return await enrichScenicStopsWithInsights(truncated, mode: mode)
    }

    private func geminiScenicStops(
        origin: CLLocationCoordinate2D,
        mode: NavigatorMode,
        travel: TravelType,
        desiredStops: Int,
        radiusMeters: Int
    ) async -> [Spot] {
        let travelMode = travel == .walking ? "walking" : "driving"
        let radiusKM = max(0.5, Double(radiusMeters) / 1000.0)

        guard let waypoints = try? await GeminiService().generateThemedWaypoints(
            lat: origin.latitude,
            lng: origin.longitude,
            travelMode: travelMode,
            radiusKM: radiusKM,
            theme: mode.rawValue,
            stops: desiredStops
        ) else {
            return []
        }

        var result: [Spot] = []
        var seen = Set<String>()
        for waypoint in waypoints {
            if result.count >= desiredStops { break }

            let coordinate = CLLocationCoordinate2D(latitude: waypoint.lat, longitude: waypoint.lng)
            guard distance(from: origin, to: coordinate) <= Double(radiusMeters) else { continue }

            let name = waypoint.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }

            let key = "\(name.lowercased())|\(String(format: "%.5f", coordinate.latitude))|\(String(format: "%.5f", coordinate.longitude))"
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            let cleanedDesc = waypoint.description.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedAddress = waypoint.address.trimmingCharacters(in: .whitespacesAndNewlines)
            let description: String
            if !cleanedDesc.isEmpty, !cleanedAddress.isEmpty {
                description = "\(cleanedDesc) • \(cleanedAddress)"
            } else if !cleanedDesc.isEmpty {
                description = cleanedDesc
            } else if !cleanedAddress.isEmpty {
                description = cleanedAddress
            } else {
                description = "Worth visiting for this route theme."
            }

            result.append(
                Spot(
                    id: UUID(),
                    name: name,
                    category: fallbackCategory(for: mode, index: result.count),
                    shortDescription: description,
                    coordinate: coordinate,
                    modeTags: [mode],
                    travelTags: [travel],
                    googlePlaceID: nil
                )
            )
        }

        return result
    }

    private func desiredScenicStopCount(
        desiredDurationMinutes: Int,
        travel: TravelType,
        detour: DetourLevel
    ) -> Int {
        let base = travel == .walking ? max(1, desiredDurationMinutes / 10) : max(1, desiredDurationMinutes / 15)
        let detourBoost: Int
        switch detour {
        case .light: detourBoost = 0
        case .moderate: detourBoost = 1
        case .bold: detourBoost = 2
        }

        let maxStops = travel == .walking ? 8 : 10
        return min(max(1, base + detourBoost), maxStops)
    }

    private func fallbackNearbyCandidates(
        near origin: CLLocationCoordinate2D,
        mode: NavigatorMode,
        limit: Int,
        radiusMeters: Int
    ) -> [DestinationCandidate] {
        let titles: [String]
        switch mode {
        case .adventure: titles = ["Street Art Spot", "Scenic View", "Riverside Walk", "Hidden Alley"]
        case .foodie: titles = ["Local Cafe", "Neighborhood Market", "Bakery Stop", "Food Street"]
        case .nature: titles = ["City Park", "Green Trail", "Waterfront", "Botanical Corner"]
        case .culture: titles = ["Art Gallery Area", "Book District", "Historic Block", "Museum Quarter"]
        case .social: titles = ["Public Plaza", "Lively Corner", "Patio District", "Community Hub"]
        case .mystery: titles = ["Scenic Detour", "Interesting Stop", "Hidden Gem", "Local Favorite"]
        }

        let radiusDegrees = max(0.002, min(Double(radiusMeters), 5_000) / 111_000.0)

        return (0..<min(limit, titles.count)).map { idx in
            let angle = (Double(idx) * 67.0).truncatingRemainder(dividingBy: 360.0) * .pi / 180.0
            let distanceScale = 0.35 + (Double(idx) * 0.08)
            let offset = min(radiusDegrees * distanceScale, radiusDegrees * 0.85)
            return DestinationCandidate(
                name: titles[idx],
                subtitle: "Close to your current area",
                coordinate: CLLocationCoordinate2D(
                    latitude: origin.latitude + (cos(angle) * offset),
                    longitude: origin.longitude + (sin(angle) * offset)
                ),
                placeID: nil
            )
        }
    }

    private func fallbackScenicStops(
        around center: CLLocationCoordinate2D,
        mode: NavigatorMode,
        travel: TravelType,
        desiredStops: Int,
        desiredDurationMinutes: Int
    ) -> [Spot] {
        let fallbackRadius = travel == .walking
            ? min(5_000, max(1_500, desiredDurationMinutes * 85))
            : min(20_000, max(4_000, desiredDurationMinutes * 300))
        let candidates = fallbackNearbyCandidates(near: center, mode: mode, limit: desiredStops, radiusMeters: fallbackRadius)
        return candidates.enumerated().map { index, candidate in
            Spot(
                id: UUID(),
                name: candidate.name,
                category: fallbackCategory(for: mode, index: index),
                shortDescription: candidate.subtitle,
                coordinate: candidate.coordinate,
                modeTags: [mode],
                travelTags: [travel],
                googlePlaceID: nil
            )
        }
    }

    private func ensureScenicStopCount(
        _ scenicStops: [Spot],
        targetCount: Int,
        around center: CLLocationCoordinate2D,
        mode: NavigatorMode,
        travel: TravelType
    ) -> [Spot] {
        guard targetCount > 0 else { return [] }
        if scenicStops.count >= targetCount {
            return Array(scenicStops.prefix(targetCount))
        }

        var result = scenicStops
        let needed = targetCount - result.count
        let fillers = fallbackScenicStops(
            around: center,
            mode: mode,
            travel: travel,
            desiredStops: needed,
            desiredDurationMinutes: max(20, targetCount * (travel == .walking ? 12 : 10))
        )

        for filler in fillers where result.count < targetCount {
            let alreadyExists = result.contains {
                distance(from: $0.coordinate, to: filler.coordinate) < 100
            }
            if !alreadyExists {
                result.append(filler)
            }
        }

        return Array(result.prefix(targetCount))
    }

    private func fallbackCategory(for mode: NavigatorMode, index: Int) -> SpotCategory {
        switch mode {
        case .foodie: return index % 2 == 0 ? .cafe : .market
        case .nature: return index % 2 == 0 ? .park : .viewpoint
        case .culture: return index % 2 == 0 ? .gallery : .bookstore
        case .adventure: return index % 2 == 0 ? .mural : .viewpoint
        case .social: return index % 2 == 0 ? .patio : .restaurant
        case .mystery: return .viewpoint
        }
    }

    private func deduplicated(_ items: [DestinationCandidate], limit: Int) -> [DestinationCandidate] {
        var result: [DestinationCandidate] = []

        for item in items {
            if result.count >= limit { break }

            let tooClose = result.contains { existing in
                distance(from: existing.coordinate, to: item.coordinate) < 100
            }
            if tooClose { continue }
            result.append(item)
        }

        return result
    }

    private func hardDetourBudgetMeters(
        for travel: TravelType,
        desiredDurationMinutes: Int,
        detour: DetourLevel,
        extraMinutesTarget: Int
    ) -> Double {
        let speedMetersPerMinute: Double = travel == .walking ? 80 : 500
        let detourMultiplier: Double
        switch detour {
        case .light: detourMultiplier = 0.8
        case .moderate: detourMultiplier = 1.0
        case .bold: detourMultiplier = 1.25
        }

        let base = travel == .walking ? 1_200.0 : 4_000.0
        let durationDriven = Double(max(10, desiredDurationMinutes)) * speedMetersPerMinute * 0.4 * detourMultiplier
        let targetDriven = Double(extraMinutesTarget) * speedMetersPerMinute * detourMultiplier
        let cap = travel == .walking ? 7_000.0 : 35_000.0
        return min(cap, max(base, max(durationDriven, targetDriven)))
    }

    private func maxCorridorOffsetMeters(for travel: TravelType, desiredDurationMinutes: Int) -> Double {
        switch travel {
        case .walking:
            return min(6_000, max(2_200, Double(desiredDurationMinutes * 85)))
        case .driving:
            return min(30_000, max(7_000, Double(desiredDurationMinutes * 300)))
        }
    }

    private func estimatedMinutesForFallback(stops: [Spot], travel: TravelType) -> Int {
        let base = travel == .walking ? 16 : 12
        return max(15, base * max(1, stops.count))
    }

    private func enrichScenicStopsWithInsights(_ stops: [Spot], mode: NavigatorMode) async -> [Spot] {
        guard !stops.isEmpty else { return stops }

        let hints = stops.map { spot in
            if spot.shortDescription.isEmpty {
                return spot.name
            }
            return "\(spot.name) — \(spot.shortDescription)"
        }

        guard let insights = try? await GeminiService().learningInsights(for: hints, mode: mode.rawValue),
              !insights.isEmpty else {
            return stops
        }

        return stops.enumerated().map { index, spot in
            guard let insight = insights[index], !insight.isEmpty else { return spot }
            return Spot(
                id: spot.id,
                name: spot.name,
                category: spot.category,
                shortDescription: insight,
                coordinate: spot.coordinate,
                modeTags: spot.modeTags,
                travelTags: spot.travelTags,
                googlePlaceID: spot.googlePlaceID
            )
        }
    }

    private func estimatedFastestMinutes(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        travel: TravelType
    ) -> Int {
        let meters = distance(from: origin, to: destination)
        let speedMetersPerMinute: Double = travel == .walking ? 80 : 500
        return max(6, Int(meters / speedMetersPerMinute))
    }

    private func scenicScore(
        place: GoogleMapsService.PlaceResult,
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D
    ) -> Double {
        let direct = distance(from: origin, to: destination)
        let via = distance(from: origin, to: place.coordinate) + distance(from: place.coordinate, to: destination)
        let detourPenalty = max(0, via - direct)
        return detourPenalty - (place.rating * 120)
    }

    private func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: from.latitude, longitude: from.longitude)
            .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
    }

    private func coordinates(from polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: .init(), count: polyline.pointCount)
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: polyline.pointCount))
        return coords
    }

    private func mapKitQuery(for mode: NavigatorMode) -> String {
        switch mode {
        case .adventure: return "scenic viewpoint"
        case .foodie: return "cafe"
        case .nature: return "park"
        case .culture: return "museum"
        case .social: return "popular plaza"
        case .mystery: return "point of interest"
        }
    }

    private func spotCategory(from types: [String]) -> SpotCategory {
        if types.contains("park") { return .park }
        if types.contains("cafe") { return .cafe }
        if types.contains("book_store") { return .bookstore }
        if types.contains("art_gallery") { return .gallery }
        if types.contains("museum") { return .gallery }
        if types.contains("restaurant") { return .restaurant }
        if types.contains("tourist_attraction") { return .viewpoint }
        return .viewpoint
    }
}

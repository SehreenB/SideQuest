import Foundation
import Combine
import CoreLocation
import MapKit

class DiscoveryEngine: ObservableObject {
    @Published var suggestedStops: [DiscoveryStop] = []
    @Published var isLoading = false
    @Published var statusMessage: String? = nil

    struct DiscoveryStop: Identifiable, Codable {
        let id: UUID
        let name: String
        let lat: Double
        let lng: Double
        let desc: String
        var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lng) }

        init(id: UUID = UUID(), name: String, lat: Double, lng: Double, desc: String) {
            self.id = id
            self.name = name
            self.lat = lat
            self.lng = lng
            self.desc = desc
        }
    }

    /// Primary discovery: Google Places API -> ranked results
    func fetchNearbyPlaces(
        location: CLLocationCoordinate2D,
        mode: NavigatorMode,
        travel: TravelType = .walking
    ) async {
        await MainActor.run {
            suggestedStops = seedFallbackStops(around: location, mode: mode)
            isLoading = true
            statusMessage = "Loading live nearby places..."
        }

        // Primary source: Gemini local-guide nearby suggestions per selected mode.
        let geminiStops = await geminiNearbyPlaces(location: location, mode: mode, desiredCount: 12)
        if !geminiStops.isEmpty {
            let normalized = normalizedStops(
                geminiStops,
                around: location,
                travel: travel,
                minimumCount: 3,
                maximumCount: 4
            )
            await MainActor.run {
                self.suggestedStops = normalized
                self.statusMessage = nil
                self.isLoading = false
            }
            return
        }

        // Try Google Places first
        if APIKeys.googleMaps != "YOUR_GOOGLE_MAPS_API_KEY" {
            do {
                let stops = try await googleNearbyPlaces(location: location, mode: mode)

                let curatedStops = await curateDiscoveryStops(stops, mode: mode, userLocation: location)

                if curatedStops.isEmpty {
                    await MainActor.run {
                        self.suggestedStops = []
                        self.statusMessage = "No mode-matching places found from Google near your location."
                        self.isLoading = false
                    }
                    return
                }

                let normalized = normalizedStops(
                    curatedStops,
                    around: location,
                    travel: travel,
                    minimumCount: 3,
                    maximumCount: 4
                )
                await MainActor.run {
                    self.suggestedStops = normalized
                    self.statusMessage = nil
                    self.isLoading = false
                }
                return
            } catch {
                await MainActor.run {
                    self.statusMessage = "Google Places unavailable, trying Apple Maps nearby search."
                }
            }
        }

        // Fallback: MapKit local search (real place names)
        if let mapKitStops = try? await mapKitNearbyPlaces(location: location, mode: mode), !mapKitStops.isEmpty {
            let curatedStops = await curateDiscoveryStops(mapKitStops, mode: mode, userLocation: location)
            let normalized = normalizedStops(
                curatedStops,
                around: location,
                travel: travel,
                minimumCount: 3,
                maximumCount: 4
            )
            await MainActor.run {
                self.suggestedStops = normalized
                self.statusMessage = nil
                self.isLoading = false
            }
            return
        }

        // Final fallback so Explore never renders empty
        await MainActor.run {
            if self.suggestedStops.isEmpty {
                self.suggestedStops = normalizedStops(
                    self.seedFallbackStops(around: location, mode: mode),
                    around: location,
                    travel: travel,
                    minimumCount: 3,
                    maximumCount: 4
                )
            }
            self.statusMessage = "Live providers unavailable. Showing fallback places."
            self.isLoading = false
        }
    }

    private func geminiNearbyPlaces(
        location: CLLocationCoordinate2D,
        mode: NavigatorMode,
        desiredCount: Int
    ) async -> [DiscoveryStop] {
        // Use "cycle" for discovery radius (7 km) so lists are richer while still nearby.
        guard let waypoints = try? await GeminiService().generateThemedWaypoints(
            lat: location.latitude,
            lng: location.longitude,
            travelMode: "cycle",
            radiusKM: 7,
            theme: mode.rawValue,
            stops: max(6, min(14, desiredCount))
        ) else {
            return []
        }

        var seen = Set<String>()
        var stops: [DiscoveryStop] = []
        for waypoint in waypoints {
            let name = waypoint.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }

            let key = "\(name.lowercased())|\(String(format: "%.5f", waypoint.lat))|\(String(format: "%.5f", waypoint.lng))"
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            let description = waypoint.description.trimmingCharacters(in: .whitespacesAndNewlines)
            let address = waypoint.address.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalDesc: String
            if !description.isEmpty, !address.isEmpty {
                finalDesc = "\(description) • \(address)"
            } else if !description.isEmpty {
                finalDesc = description
            } else if !address.isEmpty {
                finalDesc = address
            } else {
                finalDesc = "A nearby place that matches your selected mode."
            }

            stops.append(
                DiscoveryStop(
                    name: name,
                    lat: waypoint.lat,
                    lng: waypoint.lng,
                    desc: finalDesc
                )
            )
        }

        return Array(stops.prefix(max(6, min(14, desiredCount))))
    }

    private func enrichDiscoveryStops(_ stops: [DiscoveryStop], mode: NavigatorMode) async -> [DiscoveryStop] {
        guard !stops.isEmpty else { return stops }

        let hintLines = stops.map { stop in
            if stop.desc.isEmpty {
                return stop.name
            }
            return "\(stop.name) — \(stop.desc)"
        }

        guard let insights = try? await GeminiService().learningInsights(for: hintLines, mode: mode.rawValue),
              !insights.isEmpty else {
            return stops
        }

        return stops.enumerated().map { index, stop in
            guard let insight = insights[index], !insight.isEmpty else { return stop }
            return DiscoveryStop(
                id: stop.id,
                name: stop.name,
                lat: stop.lat,
                lng: stop.lng,
                desc: insight
            )
        }
    }

    private func curateDiscoveryStops(
        _ stops: [DiscoveryStop],
        mode: NavigatorMode,
        userLocation: CLLocationCoordinate2D
    ) async -> [DiscoveryStop] {
        guard !stops.isEmpty else { return stops }

        let hints = stops.map { stop in
            if stop.desc.isEmpty {
                return stop.name
            }
            return "\(stop.name) — \(stop.desc)"
        }

        if let curated = try? await GeminiService().curateNearbyPlaces(
            mode: mode.rawValue,
            userLocation: userLocation,
            placeHints: hints
        ), !curated.isEmpty {
            var used = Set<Int>()
            var ordered: [DiscoveryStop] = []

            for item in curated {
                guard item.index >= 0 && item.index < stops.count else { continue }
                guard !used.contains(item.index) else { continue }
                used.insert(item.index)

                let base = stops[item.index]
                let reason = item.reason.trimmingCharacters(in: .whitespacesAndNewlines)
                ordered.append(
                    DiscoveryStop(
                        id: base.id,
                        name: base.name,
                        lat: base.lat,
                        lng: base.lng,
                        desc: reason.isEmpty ? base.desc : reason
                    )
                )
            }

            for (idx, stop) in stops.enumerated() where !used.contains(idx) {
                ordered.append(stop)
            }

            return ordered
        }

        return await enrichDiscoveryStops(stops, mode: mode)
    }

    private func mapKitNearbyPlaces(
        location: CLLocationCoordinate2D,
        mode: NavigatorMode
    ) async throws -> [DiscoveryStop] {
        let origin = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let queries = mapKitQueries(for: mode)
        var allItems: [MKMapItem] = []

        for query in queries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.resultTypes = [.pointOfInterest, .address]
            request.region = MKCoordinateRegion(
                center: location,
                latitudinalMeters: 12_000,
                longitudinalMeters: 12_000
            )

            if let response = try? await MKLocalSearch(request: request).start() {
                allItems.append(contentsOf: response.mapItems)
            }
        }

        if allItems.isEmpty {
            let genericQueries = ["popular places", "points of interest", "landmarks", "restaurants", "cafes", "parks"]
            for query in genericQueries {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = query
                request.resultTypes = [.pointOfInterest, .address]
                request.region = MKCoordinateRegion(
                    center: location,
                    latitudinalMeters: 80_000,
                    longitudinalMeters: 80_000
                )
                if let response = try? await MKLocalSearch(request: request).start() {
                    allItems.append(contentsOf: response.mapItems)
                }
            }
        }

        var seen = Set<String>()
        let sorted = allItems
            .filter { item in
                let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let key = "\(name.lowercased())|\(item.location.coordinate.latitude)|\(item.location.coordinate.longitude)"
                if name.isEmpty || seen.contains(key) { return false }
                seen.insert(key)
                return true
            }
            .sorted { lhs, rhs in
                origin.distance(from: lhs.location) < origin.distance(from: rhs.location)
            }
            .prefix(12)

        return sorted.map { item in
            DiscoveryStop(
                name: item.name ?? "Nearby place",
                lat: item.location.coordinate.latitude,
                lng: item.location.coordinate.longitude,
                desc: item.placemark.title ?? "Popular nearby place"
            )
        }
    }

    private func mapKitQueries(for mode: NavigatorMode) -> [String] {
        switch mode {
        case .adventure: return ["scenic viewpoint", "tourist attraction", "landmark"]
        case .foodie: return ["cafe", "restaurant", "bakery"]
        case .nature: return ["park", "trail", "garden"]
        case .culture: return ["museum", "art gallery", "historic site"]
        case .social: return ["public plaza", "market", "live music venue"]
        case .mystery: return ["point of interest", "popular places", "landmark"]
        }
    }

    private func googleNearbyPlaces(
        location: CLLocationCoordinate2D,
        mode: NavigatorMode
    ) async throws -> [DiscoveryStop] {
        let keyword = GoogleMapsService.placesKeyword(for: mode)
        let type = GoogleMapsService.placesType(for: mode)
        async let strictMode: [GoogleMapsService.PlaceResult] = {
            (try? await GoogleMapsService.shared.searchNearby(
                location: location,
                radius: 4_500,
                type: type,
                keyword: keyword
            )) ?? []
        }()
        async let broadMode: [GoogleMapsService.PlaceResult] = {
            (try? await GoogleMapsService.shared.searchNearby(
                location: location,
                radius: 12_000,
                type: nil,
                keyword: "\(mode.rawValue.lowercased()) popular local"
            )) ?? []
        }()
        async let popularAny: [GoogleMapsService.PlaceResult] = {
            (try? await GoogleMapsService.shared.searchNearby(
                location: location,
                radius: 12_000,
                type: "tourist_attraction",
                keyword: "popular landmark local favorite"
            )) ?? []
        }()
        async let poiAny: [GoogleMapsService.PlaceResult] = {
            (try? await GoogleMapsService.shared.searchNearby(
                location: location,
                radius: 12_000,
                type: "point_of_interest",
                keyword: "popular"
            )) ?? []
        }()

        let merged = await strictMode + broadMode + popularAny + poiAny
        let origin = CLLocation(latitude: location.latitude, longitude: location.longitude)

        var seen = Set<String>()
        let deduped = merged.filter { place in
            let key: String
            if !place.placeID.isEmpty {
                key = place.placeID
            } else {
                key = "\(place.name.lowercased())|\(place.coordinate.latitude)|\(place.coordinate.longitude)"
            }
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        let ranked = deduped
            .sorted { lhs, rhs in
                if lhs.rating == rhs.rating {
                    let lDist = origin.distance(from: CLLocation(latitude: lhs.coordinate.latitude, longitude: lhs.coordinate.longitude))
                    let rDist = origin.distance(from: CLLocation(latitude: rhs.coordinate.latitude, longitude: rhs.coordinate.longitude))
                    return lDist < rDist
                }
                return lhs.rating > rhs.rating
            }
            .prefix(12)

        return ranked.map { place in
            DiscoveryStop(
                name: place.name,
                lat: place.coordinate.latitude,
                lng: place.coordinate.longitude,
                desc: place.vicinity.isEmpty ? "Popular nearby place" : place.vicinity
            )
        }
    }

    /// Gemini-powered discovery route generation
    func fetchDiscoveryRoute(city: String, mode: String) async {
        await MainActor.run { isLoading = true }

        do {
            let gemini = GeminiService()
            let stops = try await gemini.discoverStops(city: city, mode: mode, count: 5)
            await MainActor.run {
                self.suggestedStops = stops
                self.isLoading = false
            }
        } catch {
            print("Gemini discovery error: \(error)")
            // Last resort: stub data
            await MainActor.run {
                self.suggestedStops = []
                self.isLoading = false
            }
        }
    }

    private static func localFallbackStops(around location: CLLocationCoordinate2D, mode: NavigatorMode) -> [DiscoveryStop] {
        let templates: [(String, String)]
        switch mode {
        case .adventure:
            templates = [("Scenic Overlook", "A local viewpoint with character"), ("Mural Block", "Street art and hidden alleys nearby"), ("Historic Corner", "Unexpected details worth a stop"), ("Riverside Path", "A quieter scenic stretch")]
        case .foodie:
            templates = [("Neighborhood Cafe", "A cozy place locals recommend"), ("Local Bakery", "Fresh pastries and coffee"), ("Market Stop", "Small vendors and quick bites"), ("Street Food Spot", "Casual local flavors nearby")]
        case .nature:
            templates = [("Pocket Park", "Green space close to your route"), ("Waterfront Point", "Relaxed path with open views"), ("Garden Walk", "Quiet paths and trees"), ("Trail Access", "A nearby scenic walk")]
        case .culture:
            templates = [("Gallery Corner", "Creative local displays"), ("Book District", "Independent book and art shops"), ("Historic Block", "Architecture and stories nearby"), ("Museum Area", "Culture-focused detour option")]
        case .social:
            templates = [("Community Plaza", "Lively local gathering space"), ("Patio Strip", "Casual social venues nearby"), ("Market Square", "Shops and people-watching"), ("Live Corner", "Popular local hangout spot")]
        case .mystery:
            templates = [("Hidden Gem", "A surprise stop to explore"), ("Curious Corner", "Unexpected local spot"), ("Secret View", "A quiet scenic reveal"), ("Lucky Detour", "A fun unknown nearby")]
        }

        let base = templates.prefix(4)
        return base.enumerated().map { index, item in
            let angle = (Double(index) * 95.0) * .pi / 180.0
            let offset = 0.0035 + (Double(index) * 0.001)
            return DiscoveryStop(
                name: item.0,
                lat: location.latitude + (cos(angle) * offset),
                lng: location.longitude + (sin(angle) * offset),
                desc: item.1
            )
        }
    }

    private func seedFallbackStops(around location: CLLocationCoordinate2D, mode: NavigatorMode) -> [DiscoveryStop] {
        let matching = SeedData.spots.filter { $0.modeTags.contains(mode) }
        if !matching.isEmpty {
            return Array(matching.prefix(8)).map { spot in
                DiscoveryStop(
                    name: spot.name,
                    lat: spot.coordinate.latitude,
                    lng: spot.coordinate.longitude,
                    desc: spot.shortDescription
                )
            }
        }
        return Self.localFallbackStops(around: location, mode: mode)
    }

    private func normalizedStops(
        _ stops: [DiscoveryStop],
        around origin: CLLocationCoordinate2D,
        travel: TravelType,
        minimumCount: Int,
        maximumCount: Int
    ) -> [DiscoveryStop] {
        guard !stops.isEmpty else { return [] }

        let metersPerMinute: Double = travel == .walking ? 80 : 500
        let maxDistance = metersPerMinute * 15.0 // 15-minute radius window
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)

        let sorted = stops
            .map { stop -> (DiscoveryStop, CLLocationDistance) in
                let distance = originLocation.distance(
                    from: CLLocation(latitude: stop.lat, longitude: stop.lng)
                )
                return (stop, distance)
            }
            .sorted { $0.1 < $1.1 }

        var result = sorted
            .filter { $0.1 <= maxDistance }
            .map(\.0)

        if result.count > maximumCount {
            result = Array(result.prefix(maximumCount))
        }

        if result.count < minimumCount {
            for (stop, _) in sorted where !result.contains(where: { $0.id == stop.id }) {
                result.append(stop)
                if result.count >= maximumCount { break }
            }
        }

        return Array(result.prefix(maximumCount))
    }
}

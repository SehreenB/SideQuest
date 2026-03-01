import Foundation
import CoreLocation
import MapKit

/// Uses Google Maps REST APIs (Directions, Places, Geocoding) for data.
final class GoogleMapsService {
    static let shared = GoogleMapsService()
    private let apiKey = APIKeys.googleMaps

    // MARK: - Directions API

    struct DirectionsResult {
        let polylinePoints: [CLLocationCoordinate2D]
        let durationSeconds: Int
        let distanceMeters: Int
        let durationText: String
        let distanceText: String
        let instructions: [NavigationInstruction]
    }

    func getDirections(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D] = [],
        mode: String = "walking",
        alternatives: Bool = false
    ) async throws -> DirectionsResult {
        var urlComponents = URLComponents(string: "https://maps.googleapis.com/maps/api/directions/json")!
        var queryItems = [
            URLQueryItem(name: "origin", value: "\(origin.latitude),\(origin.longitude)"),
            URLQueryItem(name: "destination", value: "\(destination.latitude),\(destination.longitude)"),
            URLQueryItem(name: "mode", value: mode),
            URLQueryItem(name: "alternatives", value: alternatives ? "true" : "false"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        if !waypoints.isEmpty {
            let waypointValue = waypoints.map { "\($0.latitude),\($0.longitude)" }.joined(separator: "|")
            queryItems.append(URLQueryItem(name: "waypoints", value: waypointValue))
        }

        urlComponents.queryItems = queryItems
        guard let url = urlComponents.url else { throw GoogleMapsError.invalidURL }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let routes = json["routes"] as? [[String: Any]],
            let route = routes.first
        else {
            throw GoogleMapsError.noRoutes
        }

        return try parseDirectionsRoute(route)
    }

    // MARK: - Places Nearby Search

    struct PlaceResult: Identifiable {
        let id = UUID()
        let name: String
        let coordinate: CLLocationCoordinate2D
        let types: [String]
        let rating: Double
        let vicinity: String
        let placeID: String
        let photoReference: String?
    }

    struct AutocompletePrediction: Identifiable {
        let id = UUID()
        let placeID: String
        let primaryText: String
        let secondaryText: String
        let fullText: String
    }

    struct PlaceDetailsResult {
        let placeID: String
        let name: String
        let formattedAddress: String
        let coordinate: CLLocationCoordinate2D
        let openingHours: [String]
        let photoReferences: [String]
    }

    func autocompletePlaces(
        input: String,
        location: CLLocationCoordinate2D? = nil,
        radius: Int = 5000
    ) async throws -> [AutocompletePrediction] {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        if let google = try? await googleAutocompletePlaces(input: trimmed, location: location, radius: radius), !google.isEmpty {
            return google
        }

        return try await mapKitAutocompletePlaces(input: trimmed, location: location)
    }

    private func googleAutocompletePlaces(
        input: String,
        location: CLLocationCoordinate2D?,
        radius: Int
    ) async throws -> [AutocompletePrediction] {
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/place/autocomplete/json")!
        var queryItems = [
            URLQueryItem(name: "input", value: input),
            URLQueryItem(name: "key", value: apiKey)
        ]

        if let location {
            queryItems.append(URLQueryItem(name: "location", value: "\(location.latitude),\(location.longitude)"))
            queryItems.append(URLQueryItem(name: "radius", value: "\(radius)"))
            queryItems.append(URLQueryItem(name: "strictbounds", value: "true"))
        }

        components.queryItems = queryItems
        guard let url = components.url else { throw GoogleMapsError.invalidURL }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        let status = (json["status"] as? String) ?? ""
        guard status == "OK" || status == "ZERO_RESULTS" else {
            return []
        }

        guard let predictions = json["predictions"] as? [[String: Any]] else {
            return []
        }

        return predictions.compactMap { prediction in
            guard
                let placeID = prediction["place_id"] as? String,
                let structuredFormatting = prediction["structured_formatting"] as? [String: Any],
                let primary = structuredFormatting["main_text"] as? String,
                let fullText = prediction["description"] as? String
            else {
                return nil
            }

            return AutocompletePrediction(
                placeID: placeID,
                primaryText: primary,
                secondaryText: structuredFormatting["secondary_text"] as? String ?? "",
                fullText: fullText
            )
        }
    }

    private func mapKitAutocompletePlaces(
        input: String,
        location: CLLocationCoordinate2D?
    ) async throws -> [AutocompletePrediction] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = input
        request.resultTypes = [.address, .pointOfInterest]

        if let location {
            request.region = MKCoordinateRegion(
                center: location,
                latitudinalMeters: 20_000,
                longitudinalMeters: 20_000
            )
        }

        let response = try await MKLocalSearch(request: request).start()
        let centerLocation = location.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }

        let filtered = response.mapItems.filter { item in
            guard let centerLocation else { return true }
            let itemLocation = item.location
            return centerLocation.distance(from: itemLocation) <= 10_000
        }

        return Array(filtered.prefix(6)).compactMap { item in
            let name = item.name ?? input

            return AutocompletePrediction(
                placeID: "",
                primaryText: name,
                secondaryText: "Nearby result",
                fullText: name
            )
        }
    }

    func placeDetails(placeID: String) async throws -> PlaceDetailsResult? {
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/place/details/json")!
        components.queryItems = [
            URLQueryItem(name: "place_id", value: placeID),
            URLQueryItem(name: "fields", value: "place_id,name,formatted_address,geometry,opening_hours,photos"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        guard let url = components.url else { throw GoogleMapsError.invalidURL }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let result = json["result"] as? [String: Any],
            let geometry = result["geometry"] as? [String: Any],
            let location = geometry["location"] as? [String: Any],
            let lat = location["lat"] as? Double,
            let lng = location["lng"] as? Double
        else {
            return nil
        }

        let openingHours = ((result["opening_hours"] as? [String: Any])?["weekday_text"] as? [String]) ?? []
        let photos = (result["photos"] as? [[String: Any]] ?? []).compactMap { $0["photo_reference"] as? String }

        return PlaceDetailsResult(
            placeID: result["place_id"] as? String ?? placeID,
            name: result["name"] as? String ?? "Destination",
            formattedAddress: result["formatted_address"] as? String ?? "",
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            openingHours: openingHours,
            photoReferences: photos
        )
    }

    func searchNearby(
        location: CLLocationCoordinate2D,
        radius: Int = 1000,
        type: String? = nil,
        keyword: String? = nil
    ) async throws -> [PlaceResult] {
        var urlComponents = URLComponents(string: "https://maps.googleapis.com/maps/api/place/nearbysearch/json")!
        var queryItems = [
            URLQueryItem(name: "location", value: "\(location.latitude),\(location.longitude)"),
            URLQueryItem(name: "radius", value: "\(radius)"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        if let type {
            queryItems.append(URLQueryItem(name: "type", value: type))
        }

        if let keyword {
            queryItems.append(URLQueryItem(name: "keyword", value: keyword))
        }

        urlComponents.queryItems = queryItems
        guard let url = urlComponents.url else { throw GoogleMapsError.invalidURL }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let results = json["results"] as? [[String: Any]]
        else {
            return []
        }

        return results.compactMap { result in
            guard
                let name = result["name"] as? String,
                let geometry = result["geometry"] as? [String: Any],
                let placeLocation = geometry["location"] as? [String: Any],
                let lat = placeLocation["lat"] as? Double,
                let lng = placeLocation["lng"] as? Double
            else {
                return nil
            }

            return PlaceResult(
                name: name,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                types: result["types"] as? [String] ?? [],
                rating: result["rating"] as? Double ?? 0,
                vicinity: result["vicinity"] as? String ?? "",
                placeID: result["place_id"] as? String ?? "",
                photoReference: (result["photos"] as? [[String: Any]])?.first?["photo_reference"] as? String
            )
        }
    }

    func placePhotoURL(photoReference: String, maxWidth: Int = 400) -> URL? {
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/place/photo")!
        components.queryItems = [
            URLQueryItem(name: "maxwidth", value: "\(maxWidth)"),
            URLQueryItem(name: "photo_reference", value: photoReference),
            URLQueryItem(name: "key", value: apiKey)
        ]
        return components.url
    }

    // MARK: - Geocoding

    struct GeocodingResult {
        let coordinate: CLLocationCoordinate2D
        let formattedAddress: String
    }

    func geocode(address: String) async throws -> GeocodingResult? {
        var urlComponents = URLComponents(string: "https://maps.googleapis.com/maps/api/geocode/json")!
        urlComponents.queryItems = [
            URLQueryItem(name: "address", value: address),
            URLQueryItem(name: "key", value: apiKey)
        ]

        guard let url = urlComponents.url else { throw GoogleMapsError.invalidURL }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let results = json["results"] as? [[String: Any]],
            let first = results.first,
            let geometry = first["geometry"] as? [String: Any],
            let location = geometry["location"] as? [String: Any],
            let lat = location["lat"] as? Double,
            let lng = location["lng"] as? Double
        else {
            return nil
        }

        return GeocodingResult(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            formattedAddress: first["formatted_address"] as? String ?? address
        )
    }

    // MARK: - Polyline Decoder

    /// Decodes a Google encoded polyline string into coordinates.
    static func decodePolyline(_ encoded: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        var index = encoded.startIndex
        var lat: Int = 0
        var lng: Int = 0

        while index < encoded.endIndex {
            var result: Int = 0
            var shift: Int = 0
            var byte: Int

            repeat {
                byte = Int(encoded[index].asciiValue ?? 0) - 63
                index = encoded.index(after: index)
                result |= (byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20

            let dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            lat += dlat

            result = 0
            shift = 0
            repeat {
                byte = Int(encoded[index].asciiValue ?? 0) - 63
                index = encoded.index(after: index)
                result |= (byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20

            let dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            lng += dlng

            coordinates.append(CLLocationCoordinate2D(
                latitude: Double(lat) / 1e5,
                longitude: Double(lng) / 1e5
            ))
        }

        return coordinates
    }

    // MARK: - Helpers

    static func placesKeyword(for mode: NavigatorMode) -> String {
        switch mode {
        case .adventure: return "street art mural viewpoint scenic"
        case .foodie: return "cafe bakery market local"
        case .nature: return "park garden waterfront trail"
        case .culture: return "bookstore gallery museum historic"
        case .social: return "patio plaza lively area"
        case .mystery: return "hidden gem local favorite"
        }
    }

    static func placesType(for mode: NavigatorMode) -> String? {
        switch mode {
        case .adventure: return "tourist_attraction"
        case .foodie: return "cafe"
        case .nature: return "park"
        case .culture: return "museum"
        case .social: return "bar"
        case .mystery: return nil
        }
    }

    private func parseDirectionsRoute(_ route: [String: Any]) throws -> DirectionsResult {
        var polylineCoords: [CLLocationCoordinate2D] = []
        if
            let overviewPolyline = route["overview_polyline"] as? [String: Any],
            let points = overviewPolyline["points"] as? String
        {
            polylineCoords = Self.decodePolyline(points)
        }

        var totalDuration = 0
        var totalDistance = 0
        var durationText = ""
        var distanceText = ""
        var instructions: [NavigationInstruction] = []

        if let legs = route["legs"] as? [[String: Any]] {
            for leg in legs {
                if
                    let duration = leg["duration"] as? [String: Any],
                    let value = duration["value"] as? Int
                {
                    totalDuration += value
                    durationText = duration["text"] as? String ?? durationText
                }

                if
                    let distance = leg["distance"] as? [String: Any],
                    let value = distance["value"] as? Int
                {
                    totalDistance += value
                    distanceText = distance["text"] as? String ?? distanceText
                }

                if let steps = leg["steps"] as? [[String: Any]] {
                    for step in steps {
                        let htmlInstruction = step["html_instructions"] as? String ?? "Continue"
                        let plainInstruction = htmlInstruction
                            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                            .replacingOccurrences(of: "&nbsp;", with: " ")
                            .replacingOccurrences(of: "&amp;", with: "&")
                            .trimmingCharacters(in: .whitespacesAndNewlines)

                        let stepDistance = ((step["distance"] as? [String: Any])?["value"] as? Int) ?? 0
                        let stepDuration = ((step["duration"] as? [String: Any])?["value"] as? Int) ?? 0

                        if
                            let endLocation = step["end_location"] as? [String: Any],
                            let lat = endLocation["lat"] as? Double,
                            let lng = endLocation["lng"] as? Double
                        {
                            instructions.append(NavigationInstruction(
                                text: plainInstruction.isEmpty ? "Continue" : plainInstruction,
                                distanceMeters: stepDistance,
                                durationSeconds: stepDuration,
                                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)
                            ))
                        }
                    }
                }
            }
        }

        if polylineCoords.isEmpty {
            throw GoogleMapsError.noRoutes
        }

        return DirectionsResult(
            polylinePoints: polylineCoords,
            durationSeconds: totalDuration,
            distanceMeters: totalDistance,
            durationText: durationText,
            distanceText: distanceText,
            instructions: instructions
        )
    }
}

enum GoogleMapsError: LocalizedError {
    case invalidURL
    case noRoutes
    case geocodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Google Maps API URL"
        case .noRoutes: return "No routes found"
        case .geocodingFailed: return "Geocoding failed"
        }
    }
}

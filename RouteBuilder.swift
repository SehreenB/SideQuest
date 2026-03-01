import Foundation
import MapKit

enum RouteBuilder {

    /// Build a polyline through the given stops.
    /// Tries Google Directions API first, falls back to Apple MapKit.
    static func buildPolyline(
        stops: [CLLocationCoordinate2D],
        transport: MKDirectionsTransportType
    ) async -> MKPolyline? {
        guard stops.count >= 2 else { return nil }

        // Try Google Directions first
        if APIKeys.googleMaps != "YOUR_GOOGLE_MAPS_API_KEY" {
            do {
                let origin = stops.first!
                let dest = stops.last!
                let waypoints = Array(stops.dropFirst().dropLast())
                let mode = transport == .walking ? "walking" : "driving"

                let result = try await GoogleMapsService.shared.getDirections(
                    origin: origin,
                    destination: dest,
                    waypoints: waypoints,
                    mode: mode
                )

                guard !result.polylinePoints.isEmpty else { throw GoogleMapsError.noRoutes }
                return MKPolyline(coordinates: result.polylinePoints, count: result.polylinePoints.count)
            } catch {
                print("Google Directions failed, using MapKit: \(error)")
            }
        }

        // Fallback: Apple MapKit directions
        return await buildWithMapKit(stops: stops, transport: transport)
    }

    /// Get route timing info from Google Directions
    static func getRouteInfo(
        stops: [CLLocationCoordinate2D],
        mode: String = "walking"
    ) async -> (durationMinutes: Int, distanceKm: Double)? {
        guard stops.count >= 2, APIKeys.googleMaps != "YOUR_GOOGLE_MAPS_API_KEY" else { return nil }

        do {
            let origin = stops.first!
            let dest = stops.last!
            let waypoints = Array(stops.dropFirst().dropLast())

            let result = try await GoogleMapsService.shared.getDirections(
                origin: origin,
                destination: dest,
                waypoints: waypoints,
                mode: mode
            )

            return (
                durationMinutes: result.durationSeconds / 60,
                distanceKm: Double(result.distanceMeters) / 1000.0
            )
        } catch {
            return nil
        }
    }

    // MARK: - MapKit Fallback

    private static func buildWithMapKit(
        stops: [CLLocationCoordinate2D],
        transport: MKDirectionsTransportType
    ) async -> MKPolyline? {
        var allCoords: [CLLocationCoordinate2D] = []

        for i in 0..<(stops.count - 1) {
            let src = MKMapItem(
                location: CLLocation(latitude: stops[i].latitude, longitude: stops[i].longitude),
                address: nil
            )
            let dst = MKMapItem(
                location: CLLocation(latitude: stops[i + 1].latitude, longitude: stops[i + 1].longitude),
                address: nil
            )

            let req = MKDirections.Request()
            req.source = src
            req.destination = dst
            req.transportType = transport

            do {
                let res = try await MKDirections(request: req).calculate()
                if let route = res.routes.first {
                    let poly = route.polyline
                    var coords = [CLLocationCoordinate2D](repeating: .init(), count: poly.pointCount)
                    poly.getCoordinates(&coords, range: NSRange(location: 0, length: poly.pointCount))
                    allCoords.append(contentsOf: coords)
                }
            } catch {
                allCoords.append(stops[i])
                allCoords.append(stops[i + 1])
            }
        }

        return MKPolyline(coordinates: allCoords, count: allCoords.count)
    }
}

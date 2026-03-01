import SwiftUI
import GoogleMaps
import CoreLocation
import UIKit

/// A SwiftUI wrapper around GMSMapView.
struct GoogleMapView: UIViewRepresentable {
    var markers: [MapMarker]
    var polylinePath: [CLLocationCoordinate2D]
    var showsUserLocation: Bool
    var initialCenter: CLLocationCoordinate2D
    var initialZoom: Float
    var polylineColor: UIColor
    var markerColor: UIColor
    var userCoordinate: CLLocationCoordinate2D?
    var userBearing: CLLocationDirection?
    var followUser: Bool
    var showInitialOverviewBeforeFollow: Bool
    var forceRecenterToken: Int
    var alwaysFitMarkersWhenNotFollowing: Bool
    var onUserGesture: (() -> Void)?
    var routeStartIndicator: RouteStartIndicator?

    init(
        markers: [MapMarker] = [],
        polylinePath: [CLLocationCoordinate2D] = [],
        showsUserLocation: Bool = true,
        center: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832),
        zoom: Float = 14,
        polylineColor: UIColor = UIColor(red: 194/255, green: 109/255, blue: 74/255, alpha: 1),
        markerColor: UIColor = UIColor(red: 122/255, green: 155/255, blue: 142/255, alpha: 1),
        userCoordinate: CLLocationCoordinate2D? = nil,
        userBearing: CLLocationDirection? = nil,
        followUser: Bool = false,
        showInitialOverviewBeforeFollow: Bool = false,
        forceRecenterToken: Int = 0,
        alwaysFitMarkersWhenNotFollowing: Bool = false,
        onUserGesture: (() -> Void)? = nil,
        routeStartIndicator: RouteStartIndicator? = nil
    ) {
        self.markers = markers
        self.polylinePath = polylinePath
        self.showsUserLocation = showsUserLocation
        self.initialCenter = center
        self.initialZoom = zoom
        self.polylineColor = polylineColor
        self.markerColor = markerColor
        self.userCoordinate = userCoordinate
        self.userBearing = userBearing
        self.followUser = followUser
        self.showInitialOverviewBeforeFollow = showInitialOverviewBeforeFollow
        self.forceRecenterToken = forceRecenterToken
        self.alwaysFitMarkersWhenNotFollowing = alwaysFitMarkersWhenNotFollowing
        self.onUserGesture = onUserGesture
        self.routeStartIndicator = routeStartIndicator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition(
            latitude: initialCenter.latitude,
            longitude: initialCenter.longitude,
            zoom: initialZoom
        )
        let options = GMSMapViewOptions()
        options.camera = camera

        let mapView = GMSMapView(options: options)
        mapView.isMyLocationEnabled = showsUserLocation
        mapView.settings.myLocationButton = showsUserLocation
        mapView.settings.compassButton = true
        mapView.mapType = .normal
        mapView.delegate = context.coordinator

        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.parent = self
        mapView.clear()

        for marker in markers {
            let gmsMarker = GMSMarker(position: marker.coordinate)
            gmsMarker.title = marker.title
            gmsMarker.snippet = marker.snippet
            gmsMarker.icon = GMSMarker.markerImage(with: UIColor(
                red: CGFloat(marker.color.r),
                green: CGFloat(marker.color.g),
                blue: CGFloat(marker.color.b),
                alpha: 1
            ))
            gmsMarker.map = mapView
        }

        if !polylinePath.isEmpty {
            let path = GMSMutablePath()
            for coord in polylinePath {
                path.add(coord)
            }
            let polyline = GMSPolyline(path: path)
            polyline.strokeWidth = 5
            polyline.strokeColor = polylineColor
            polyline.map = mapView
        }

        if let routeStartIndicator {
            let marker = GMSMarker(position: routeStartIndicator.coordinate)
            marker.title = "Route start"
            marker.iconView = routeStartArrowView(bearing: routeStartIndicator.bearingDegrees)
            marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
            marker.zIndex = 20
            marker.map = mapView
        }

        if context.coordinator.lastForceRecenterToken != forceRecenterToken {
            context.coordinator.lastForceRecenterToken = forceRecenterToken
            context.coordinator.followActivationDate = nil
            context.coordinator.didShowInitialOverview = true
            context.coordinator.lastFollowCoordinate = nil
            context.coordinator.didScheduleFollowAfterOverview = false
        }

        if followUser, let userCoordinate {
            if showInitialOverviewBeforeFollow, !context.coordinator.didShowInitialOverview {
                var hasAnyCoordinate = false
                var bounds = GMSCoordinateBounds()

                for marker in markers {
                    bounds = bounds.includingCoordinate(marker.coordinate)
                    hasAnyCoordinate = true
                }

                for coord in polylinePath {
                    bounds = bounds.includingCoordinate(coord)
                    hasAnyCoordinate = true
                }

                bounds = bounds.includingCoordinate(userCoordinate)
                hasAnyCoordinate = true

                if hasAnyCoordinate {
                    let update = GMSCameraUpdate.fit(bounds, withPadding: 70)
                    mapView.animate(with: update)
                }

                context.coordinator.didShowInitialOverview = true
                context.coordinator.followActivationDate = Date().addingTimeInterval(1.2)
                context.coordinator.didPerformInitialFit = true

                if !context.coordinator.didScheduleFollowAfterOverview {
                    context.coordinator.didScheduleFollowAfterOverview = true
                    let followCoordinate = userCoordinate
                    let followBearing = userBearing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                        applyFollowCamera(
                            mapView: mapView,
                            userCoordinate: followCoordinate,
                            userBearing: followBearing
                        )
                    }
                }
                return
            }

            if let followActivationDate = context.coordinator.followActivationDate, Date() < followActivationDate {
                return
            }

            if let last = context.coordinator.lastFollowCoordinate {
                let moved = CLLocation(latitude: last.latitude, longitude: last.longitude)
                    .distance(from: CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude))
                let hasValidBearing: Bool = {
                    guard let userBearing else { return false }
                    return userBearing >= 0 && userBearing <= 360
                }()
                let bearing = hasValidBearing ? (userBearing ?? mapView.camera.bearing) : mapView.camera.bearing
                let bearingDelta = abs(bearing - mapView.camera.bearing)
                if moved < 2.5, bearingDelta < 8 {
                    return
                }
            }
            context.coordinator.lastFollowCoordinate = userCoordinate
            applyFollowCamera(mapView: mapView, userCoordinate: userCoordinate, userBearing: userBearing)
            context.coordinator.didPerformInitialFit = true
            return
        }

        let markerSignature = markers
            .map { marker in "\(marker.title)|\(marker.coordinate.latitude.rounded(toPlaces: 5))|\(marker.coordinate.longitude.rounded(toPlaces: 5))" }
            .joined(separator: ";")
        let shouldRefitForMarkerChanges = alwaysFitMarkersWhenNotFollowing && context.coordinator.lastMarkersSignature != markerSignature

        if !markers.isEmpty, (!context.coordinator.didPerformInitialFit || shouldRefitForMarkerChanges) {
            let bounds = markers.reduce(GMSCoordinateBounds()) { bounds, marker in
                bounds.includingCoordinate(marker.coordinate)
            }
            let update = GMSCameraUpdate.fit(bounds, withPadding: 60)
            mapView.animate(with: update)
            context.coordinator.didPerformInitialFit = true
            context.coordinator.lastMarkersSignature = markerSignature
        } else if !markers.isEmpty, context.coordinator.lastMarkersSignature.isEmpty {
            context.coordinator.lastMarkersSignature = markerSignature
        }
    }

    final class Coordinator: NSObject {
        var parent: GoogleMapView?
        var didPerformInitialFit = false
        var didShowInitialOverview = false
        var didScheduleFollowAfterOverview = false
        var followActivationDate: Date?
        var lastForceRecenterToken: Int = 0
        var lastFollowCoordinate: CLLocationCoordinate2D?
        var lastMarkersSignature: String = ""
    }

    private func offsetCoordinate(
        from coordinate: CLLocationCoordinate2D,
        distanceMeters: CLLocationDistance,
        bearing: CLLocationDirection
    ) -> CLLocationCoordinate2D {
        let earthRadius = 6_371_000.0
        let distanceRadians = distanceMeters / earthRadius
        let bearingRadians = bearing * .pi / 180
        let lat1 = coordinate.latitude * .pi / 180
        let lon1 = coordinate.longitude * .pi / 180

        let lat2 = asin(
            sin(lat1) * cos(distanceRadians) +
            cos(lat1) * sin(distanceRadians) * cos(bearingRadians)
        )

        let lon2 = lon1 + atan2(
            sin(bearingRadians) * sin(distanceRadians) * cos(lat1),
            cos(distanceRadians) - sin(lat1) * sin(lat2)
        )

        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }

    private func routeStartArrowView(bearing: CLLocationDirection) -> UIView {
        let size: CGFloat = 30
        let container = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        container.backgroundColor = UIColor(red: 194/255, green: 109/255, blue: 74/255, alpha: 0.95)
        container.layer.cornerRadius = size / 2
        container.layer.borderWidth = 1.5
        container.layer.borderColor = UIColor.white.withAlphaComponent(0.95).cgColor

        let imageView = UIImageView(frame: CGRect(x: 7, y: 7, width: 16, height: 16))
        imageView.image = UIImage(systemName: "arrowtriangle.up.fill")?.withRenderingMode(.alwaysTemplate)
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.transform = CGAffineTransform(rotationAngle: CGFloat(bearing * .pi / 180.0))
        container.addSubview(imageView)
        return container
    }

    private func applyFollowCamera(
        mapView: GMSMapView,
        userCoordinate: CLLocationCoordinate2D,
        userBearing: CLLocationDirection?
    ) {
        let zoom = max(mapView.camera.zoom, 17.5)
        let hasValidBearing: Bool = {
            guard let userBearing else { return false }
            return userBearing >= 0 && userBearing <= 360
        }()
        let bearing = hasValidBearing ? (userBearing ?? mapView.camera.bearing) : mapView.camera.bearing
        let target = hasValidBearing
            ? offsetCoordinate(from: userCoordinate, distanceMeters: 90, bearing: bearing)
            : userCoordinate

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.55)
        let camera = GMSCameraPosition.camera(
            withTarget: target,
            zoom: zoom,
            bearing: bearing,
            viewingAngle: hasValidBearing ? 45 : 0
        )
        mapView.animate(to: camera)
        CATransaction.commit()
    }
}

extension GoogleMapView.Coordinator: GMSMapViewDelegate {
    func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
        guard gesture else { return }
        parent?.onUserGesture?()
    }
}

// MARK: - Marker Data

extension GoogleMapView {
    struct RouteStartIndicator {
        let coordinate: CLLocationCoordinate2D
        let bearingDegrees: CLLocationDirection
    }
}

struct MapMarker: Identifiable {
    let id = UUID()
    let title: String
    let snippet: String
    let coordinate: CLLocationCoordinate2D
    var color: MarkerColor

    struct MarkerColor {
        let r: Double
        let g: Double
        let b: Double

        static let terracotta = MarkerColor(r: 194/255, g: 109/255, b: 74/255)
        static let sage = MarkerColor(r: 122/255, g: 155/255, b: 142/255)
        static let gold = MarkerColor(r: 212/255, g: 163/255, b: 115/255)
    }
}

// MARK: - Convenience Extensions

extension GoogleMapView {
    static func forRoute(
        stops: [Spot],
        polyline: [CLLocationCoordinate2D] = [],
        showsUser: Bool = true,
        userCoordinate: CLLocationCoordinate2D? = nil,
        followUser: Bool = false
    ) -> GoogleMapView {
        let markers = stops.enumerated().map { index, stop in
            MapMarker(
                title: stop.name,
                snippet: stop.shortDescription,
                coordinate: stop.coordinate,
                color: index == 0 ? .terracotta : .sage
            )
        }

        let center = stops.first?.coordinate ?? CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)

        return GoogleMapView(
            markers: markers,
            polylinePath: polyline,
            showsUserLocation: showsUser,
            center: center,
            zoom: 14,
            userCoordinate: userCoordinate,
            userBearing: nil,
            followUser: followUser
        )
    }

    static func forExplore(
        discoveryStops: [DiscoveryEngine.DiscoveryStop],
        seedSpots: [Spot],
        center: CLLocationCoordinate2D
    ) -> GoogleMapView {
        var markers: [MapMarker] = []

        for stop in discoveryStops {
            markers.append(MapMarker(
                title: stop.name,
                snippet: stop.desc,
                coordinate: stop.coordinate,
                color: .terracotta
            ))
        }

        for spot in seedSpots {
            markers.append(MapMarker(
                title: spot.name,
                snippet: spot.shortDescription,
                coordinate: spot.coordinate,
                color: .sage
            ))
        }

        return GoogleMapView(
            markers: markers,
            showsUserLocation: true,
            center: center,
            zoom: 13
        )
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        guard places >= 0 else { return self }
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

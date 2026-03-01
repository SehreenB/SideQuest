import SwiftUI
import Combine
import CoreLocation

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let lastLatKey = "sidequest.last_location.lat"
    private let lastLngKey = "sidequest.last_location.lng"

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var location: CLLocation? = nil
    @Published var locationErrorMessage: String? = nil
    @Published var lastKnownCoordinate: CLLocationCoordinate2D? = nil

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 3
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
        if let restored = restoreLastKnownCoordinate() {
            lastKnownCoordinate = restored
        }
    }

    func requestPermission() {
        let status = manager.authorizationStatus
        authorizationStatus = status
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdates()
        default:
            break
        }
    }

    func startUpdates() {
        if location == nil, let cached = manager.location {
            location = cached
            persistLastKnownCoordinate(cached.coordinate)
        }
        manager.startUpdatingLocation()
        manager.requestLocation()
    }

    func stopUpdates() {
        manager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        DispatchQueue.main.async {
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.startUpdates()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.startUpdates()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async {
            self.location = locations.last
            if let coordinate = locations.last?.coordinate {
                self.persistLastKnownCoordinate(coordinate)
            }
            self.locationErrorMessage = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationErrorMessage = error.localizedDescription
        }
    }

    private func persistLastKnownCoordinate(_ coordinate: CLLocationCoordinate2D) {
        guard coordinate.latitude.isFinite, coordinate.longitude.isFinite else { return }
        lastKnownCoordinate = coordinate
        UserDefaults.standard.set(coordinate.latitude, forKey: lastLatKey)
        UserDefaults.standard.set(coordinate.longitude, forKey: lastLngKey)
    }

    private func restoreLastKnownCoordinate() -> CLLocationCoordinate2D? {
        guard UserDefaults.standard.object(forKey: lastLatKey) != nil,
              UserDefaults.standard.object(forKey: lastLngKey) != nil else {
            return nil
        }
        let lat = UserDefaults.standard.double(forKey: lastLatKey)
        let lng = UserDefaults.standard.double(forKey: lastLngKey)
        guard abs(lat) <= 90, abs(lng) <= 180 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

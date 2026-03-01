import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject private var loc = LocationManager()

    private var userCenter: CLLocationCoordinate2D {
        loc.location?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }

    private var userMarkers: [MapMarker] {
        guard let location = loc.location else { return [] }
        return [
            MapMarker(
                title: "You",
                snippet: "Current location",
                coordinate: location.coordinate,
                color: .terracotta
            )
        ]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                GoogleMapView(
                    markers: userMarkers,
                    polylinePath: [],
                    showsUserLocation: true,
                    center: userCenter,
                    zoom: 14,
                    userCoordinate: loc.location?.coordinate,
                    followUser: true
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))

                Button {
                    loc.requestPermission()
                    loc.startUpdates()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                        Text("Enable Location")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .navigationTitle("Map")
            .onAppear {
                loc.requestPermission()
                loc.startUpdates()
            }
        }
    }
}

import SwiftUI
import CoreLocation
import UIKit
import MapKit
import Combine

struct HomeView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var locationManager = LocationManager()
    @State private var trendingPlaces: [TrendingItem] = []
    @State private var isLoadingTrending = false
    @State private var hasLoadedTrending = false
    @State private var waitBeganAt: Date = Date()
    private let fallbackTrendingCoordinate = CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)

    private struct TrendingItem: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let distanceText: String
        let photoURL: URL?
    }

    private struct WeeklyLeaderboardEntry: Identifiable {
        let id = UUID()
        let rank: Int
        let username: String
        let points: Int

        var initials: String {
            let trimmed = username.trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            return String(trimmed.prefix(1)).uppercased()
        }
    }

    private let weeklyLeaderboard: [WeeklyLeaderboardEntry] = [
        .init(rank: 1, username: "@adventurer_sam", points: 320),
        .init(rank: 2, username: "@urban_wanderer", points: 285),
        .init(rank: 3, username: "@nature_nina", points: 240)
    ]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Good to see you,")
                            .font(ThemeFont.bodySmall)
                            .foregroundStyle(Theme.text.opacity(0.62))

                        Text("Explorer")
                            .font(ThemeFont.titleMedium)
                            .foregroundStyle(Theme.text)
                    }

                    HStack(spacing: 12) {
                        statCard(icon: "trophy", value: "\(app.user.points)", label: "Points", tint: Theme.gold)
                        statCard(icon: "flame", value: "\(app.user.streak)", label: "Day Streak", tint: Theme.terracotta)
                    }

                    NavigationLink {
                        ModeSelectionView(destination: .routeSetup)
                    } label: {
                        startRouteCard
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 12) {
                        NavigationLink {
                            ChallengesView()
                        } label: {
                            shortcutCard(icon: "target", title: "Find It", tint: Theme.sage)
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            ModeSelectionView()
                        } label: {
                            shortcutCard(icon: "mappin.circle", title: "Explore Nearby", tint: Theme.terracotta)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Trending near you")
                        .font(ThemeFont.sectionTitle)
                        .foregroundStyle(Theme.text)
                        .padding(.top, 2)

                    if isLoadingTrending && trendingPlaces.isEmpty {
                        HStack {
                            ProgressView()
                                .tint(Theme.terracotta)
                            Text("Finding popular places close to you...")
                                .font(ThemeFont.caption)
                                .foregroundStyle(Theme.text.opacity(0.65))
                        }
                        .padding(.vertical, 8)
                    } else if trendingPlaces.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(emptyTrendingMessage)
                                .font(ThemeFont.caption)
                                .foregroundStyle(Theme.text.opacity(0.65))

                            if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                                Button {
                                    openAppSettings()
                                } label: {
                                    Text("Open Location Settings")
                                        .font(ThemeFont.caption)
                                        .foregroundStyle(Theme.terracotta)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.white.opacity(0.6))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(trendingPlaces) { item in
                                    trendingCard(item: item)
                                }
                            }
                            .padding(.trailing, 6)
                        }
                    }

                    Text("Weekly Leaderboard")
                        .font(ThemeFont.sectionTitle)
                        .foregroundStyle(Theme.text)
                        .padding(.top, 4)

                    weeklyLeaderboardCard
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 10)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            waitBeganAt = Date()
            locationManager.requestPermission()
            locationManager.startUpdates()
            if let existingLocation = locationManager.location, !hasLoadedTrending {
                Task { await loadTrendingNearby(from: existingLocation.coordinate) }
            } else if let lastKnown = locationManager.lastKnownCoordinate, !hasLoadedTrending {
                Task { await loadTrendingNearby(from: lastKnown) }
            } else if !hasLoadedTrending {
                Task { await loadTrendingNearby(from: fallbackTrendingCoordinate) }
            }
        }
        .onDisappear {
            locationManager.stopUpdates()
        }
        .onChange(of: locationManager.location) { _, newLocation in
            guard let newLocation else { return }
            let shouldRefresh = !hasLoadedTrending || trendingPlaces.isEmpty || isStale(for: newLocation.coordinate)
            guard shouldRefresh else { return }
            Task { await loadTrendingNearby(from: newLocation.coordinate) }
        }
        .onChange(of: locationManager.authorizationStatus) { _, status in
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                locationManager.startUpdates()
                if let existingLocation = locationManager.location, !hasLoadedTrending {
                    Task { await loadTrendingNearby(from: existingLocation.coordinate) }
                } else if let lastKnown = locationManager.lastKnownCoordinate, !hasLoadedTrending {
                    Task { await loadTrendingNearby(from: lastKnown) }
                } else if !hasLoadedTrending {
                    Task { await loadTrendingNearby(from: fallbackTrendingCoordinate) }
                }
            }
        }
        .onReceive(locationManager.$lastKnownCoordinate.compactMap { $0 }) { coordinate in
            let shouldRefresh = !hasLoadedTrending || trendingPlaces.isEmpty
            guard shouldRefresh else { return }
            Task { await loadTrendingNearby(from: coordinate) }
        }
    }

    private func statCard(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(ThemeFont.cardValue)
                    .foregroundStyle(Theme.text)
                Text(label)
                    .font(ThemeFont.caption)
                    .foregroundStyle(Theme.text.opacity(0.62))
            }

            Spacer()
        }
        .padding(14)
        .background(.white.opacity(0.56))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Theme.text.opacity(0.08), lineWidth: 1)
        )
    }

    private var startRouteCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "safari")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .background(Theme.terracotta)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            VStack(alignment: .leading, spacing: 3) {
                Text("Start a Route")
                    .font(ThemeFont.sectionTitle)
                    .foregroundStyle(Theme.text)

                Text("Choose a mode and explore")
                    .font(ThemeFont.bodySmall)
                    .foregroundStyle(Theme.text.opacity(0.6))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.text.opacity(0.45))
        }
        .padding(20)
        .background(.white.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Theme.text.opacity(0.08), lineWidth: 1)
        )
    }

    private func shortcutCard(icon: String, title: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(ThemeFont.bodyStrong)
                .foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.white.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Theme.text.opacity(0.08), lineWidth: 1)
        )
    }

    private func trendingCard(item: TrendingItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                if let photoURL = item.photoURL {
                    AsyncImage(url: photoURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Theme.text.opacity(0.08))
                                .overlay {
                                    Image(systemName: "mappin")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(Theme.text.opacity(0.55))
                                }
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.text.opacity(0.08))
                        .overlay {
                            Image(systemName: "mappin")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Theme.text.opacity(0.55))
                        }
                }
            }
            .frame(width: 164, height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(ThemeFont.bodySmallStrong)
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)

                Text(item.subtitle)
                    .font(ThemeFont.caption)
                    .foregroundStyle(Theme.text.opacity(0.62))
                    .lineLimit(1)

                Text(item.distanceText)
                    .font(ThemeFont.caption)
                    .foregroundStyle(Theme.terracotta)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(width: 180, height: 162, alignment: .topLeading)
        .padding(10)
        .background(.white.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Theme.text.opacity(0.08), lineWidth: 1)
        )
    }

    private func isStale(for coordinate: CLLocationCoordinate2D) -> Bool {
        guard let first = trendingPlaces.first,
              let coordinatePart = first.id.split(separator: "|").last else {
            return true
        }

        let latLng = coordinatePart.split(separator: ",")
        guard latLng.count == 2,
              let lat = Double(latLng[0]),
              let lng = Double(latLng[1]) else { return true }

        let existing = CLLocation(latitude: lat, longitude: lng)
        let current = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return current.distance(from: existing) > 1200
    }

    @MainActor
    private func loadTrendingNearby(from coordinate: CLLocationCoordinate2D) async {
        isLoadingTrending = true
        defer {
            isLoadingTrending = false
            hasLoadedTrending = true
        }

        let targetMinutes = 15.0
        let walkingMetersPerMinute = 80.0
        let preferredDistance = targetMinutes * walkingMetersPerMinute
        let queryRadius = 8000
        async let landmarks: [GoogleMapsService.PlaceResult] = {
            (try? await GoogleMapsService.shared.searchNearby(
                location: coordinate,
                radius: queryRadius,
                type: "tourist_attraction",
                keyword: "famous landmark popular"
            )) ?? []
        }()
        async let culture: [GoogleMapsService.PlaceResult] = {
            (try? await GoogleMapsService.shared.searchNearby(
                location: coordinate,
                radius: queryRadius,
                type: "museum",
                keyword: "popular"
            )) ?? []
        }()
        async let food: [GoogleMapsService.PlaceResult] = {
            (try? await GoogleMapsService.shared.searchNearby(
                location: coordinate,
                radius: queryRadius,
                type: "cafe",
                keyword: "famous local favorite"
            )) ?? []
        }()

        let merged = await landmarks + culture + food
        if !merged.isEmpty {
            trendingPlaces = buildTrendingItems(
                from: merged,
                origin: coordinate,
                preferredMaxDistance: preferredDistance,
                fallbackMaxDistance: Double(queryRadius)
            )
            if !trendingPlaces.isEmpty {
                return
            }
        }

        let mapKitFallback = await mapKitTrendingFallback(
            from: coordinate,
            preferredMaxDistance: preferredDistance,
            fallbackMaxDistance: Double(queryRadius)
        )
        if !mapKitFallback.isEmpty {
            trendingPlaces = mapKitFallback
            return
        }

        let isAlreadyFallbackCity =
            abs(coordinate.latitude - fallbackTrendingCoordinate.latitude) < 0.0001 &&
            abs(coordinate.longitude - fallbackTrendingCoordinate.longitude) < 0.0001

        if !isAlreadyFallbackCity {
            let cityFallback = await mapKitTrendingFallback(
                from: fallbackTrendingCoordinate,
                preferredMaxDistance: preferredDistance,
                fallbackMaxDistance: Double(queryRadius)
            )
            trendingPlaces = cityFallback.isEmpty
                ? localTrendingFallback(from: coordinate, preferredMaxDistance: preferredDistance)
                : cityFallback
        } else {
            trendingPlaces = localTrendingFallback(from: coordinate, preferredMaxDistance: preferredDistance)
        }
    }

    private func mapKitTrendingFallback(
        from coordinate: CLLocationCoordinate2D,
        preferredMaxDistance: CLLocationDistance,
        fallbackMaxDistance: CLLocationDistance
    ) async -> [TrendingItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "popular places landmark museum cafe"
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: fallbackMaxDistance * 2,
            longitudinalMeters: fallbackMaxDistance * 2
        )

        guard let response = try? await MKLocalSearch(request: request).start() else {
            return []
        }

        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let ranked = response.mapItems
            .compactMap { item -> (MKMapItem, CLLocationDistance)? in
                let distance = origin.distance(from: item.location)
                guard distance <= fallbackMaxDistance else { return nil }
                return (item, distance)
            }
            .sorted { $0.1 < $1.1 }
        let normalized = normalizeTrendingCandidates(
            ranked,
            preferredMaxDistance: preferredMaxDistance
        )
        return normalized
            .map { item, distance in
                TrendingItem(
                    id: "\(item.name ?? UUID().uuidString)|\(item.location.coordinate.latitude),\(item.location.coordinate.longitude)",
                    title: item.name ?? "Nearby place",
                    subtitle: item.placemark.title ?? "Nearby",
                    distanceText: distanceText(distance),
                    photoURL: nil
                )
            }
    }

    private func buildTrendingItems(
        from places: [GoogleMapsService.PlaceResult],
        origin: CLLocationCoordinate2D,
        preferredMaxDistance: CLLocationDistance,
        fallbackMaxDistance: CLLocationDistance
    ) -> [TrendingItem] {
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)

        let deduped = Dictionary(grouping: places, by: { $0.placeID.isEmpty ? "\($0.name)-\($0.coordinate.latitude)-\($0.coordinate.longitude)" : $0.placeID })
            .compactMap { $0.value.max(by: { $0.rating < $1.rating }) }

        let ranked = deduped
            .compactMap { place -> (GoogleMapsService.PlaceResult, CLLocationDistance)? in
                let distance = originLocation.distance(from: CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude))
                guard distance <= fallbackMaxDistance else { return nil }
                return (place, distance)
            }
            .sorted { lhs, rhs in
                if lhs.0.rating == rhs.0.rating { return lhs.1 < rhs.1 }
                return lhs.0.rating > rhs.0.rating
            }
        let normalized = normalizeTrendingCandidates(
            ranked,
            preferredMaxDistance: preferredMaxDistance
        )

        return normalized.map { place, distance in
            TrendingItem(
                id: "\(place.placeID)|\(place.coordinate.latitude),\(place.coordinate.longitude)",
                title: place.name,
                subtitle: place.vicinity.isEmpty ? "Nearby" : place.vicinity,
                distanceText: distanceText(distance),
                photoURL: place.photoReference.flatMap { GoogleMapsService.shared.placePhotoURL(photoReference: $0) }
            )
        }
    }

    private func normalizeTrendingCandidates<T>(
        _ candidates: [(T, CLLocationDistance)],
        preferredMaxDistance: CLLocationDistance,
        minimumCount: Int = 3,
        maximumCount: Int = 5
    ) -> [(T, CLLocationDistance)] {
        guard !candidates.isEmpty else { return [] }

        let indexed = Array(candidates.enumerated())
        var selectedIndexes: [Int] = indexed
            .filter { $0.element.1 <= preferredMaxDistance }
            .map(\.offset)

        if selectedIndexes.count > maximumCount {
            selectedIndexes = Array(selectedIndexes.prefix(maximumCount))
        }

        if selectedIndexes.count < minimumCount {
            for (offset, _) in indexed where !selectedIndexes.contains(offset) {
                selectedIndexes.append(offset)
                if selectedIndexes.count >= maximumCount { break }
            }
        }

        return selectedIndexes.prefix(maximumCount).map { candidates[$0] }
    }

    private func distanceText(_ meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km away", meters / 1000)
        }
        return "\(Int(meters)) m away"
    }

    private func localTrendingFallback(
        from coordinate: CLLocationCoordinate2D,
        preferredMaxDistance: CLLocationDistance
    ) -> [TrendingItem] {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let ranked = SeedData.spots
            .map { spot -> (Spot, CLLocationDistance) in
                let distance = origin.distance(from: CLLocation(
                    latitude: spot.coordinate.latitude,
                    longitude: spot.coordinate.longitude
                ))
                return (spot, distance)
            }
            .sorted { $0.1 < $1.1 }

        let normalized = normalizeTrendingCandidates(
            ranked,
            preferredMaxDistance: preferredMaxDistance
        )

        return normalized.map { spot, distance in
            TrendingItem(
                id: "\(spot.id.uuidString)|\(spot.coordinate.latitude),\(spot.coordinate.longitude)",
                title: spot.name,
                subtitle: spot.shortDescription,
                distanceText: distanceText(distance),
                photoURL: nil
            )
        }
    }

    private var emptyTrendingMessage: String {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            return "Location is off for SideQuest. Enable it to see famous places near you."
        case .notDetermined:
            return "Allow location to see famous places near you."
        default:
            if Date().timeIntervalSince(waitBeganAt) > 8 {
                return "No GPS fix yet. If you are on Simulator, set Features > Location to a city route."
            }
            return "Waiting for your current location..."
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private var weeklyLeaderboardCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(weeklyLeaderboard.enumerated()), id: \.element.id) { index, entry in
                HStack(spacing: 10) {
                    Text("\(entry.rank)")
                        .font(ThemeFont.bodySmallStrong)
                        .foregroundStyle(Theme.gold)
                        .frame(width: 16, alignment: .leading)

                    Text(entry.initials)
                        .font(ThemeFont.caption)
                        .foregroundStyle(Theme.text.opacity(0.75))
                        .frame(width: 32, height: 32)
                        .background(Theme.text.opacity(0.07))
                        .clipShape(Circle())

                    Text(entry.username)
                        .font(ThemeFont.bodyStrong)
                        .foregroundStyle(Theme.text)

                    Spacer()

                    Text("\(entry.points) pts")
                        .font(ThemeFont.bodySmall)
                        .foregroundStyle(Theme.text.opacity(0.68))
                }
                .padding(.vertical, 13)
                .padding(.horizontal, 14)

                if index < weeklyLeaderboard.count - 1 {
                    Divider()
                        .overlay(Theme.text.opacity(0.08))
                }
            }
        }
        .background(.white.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Theme.text.opacity(0.08), lineWidth: 1)
        )
    }
}

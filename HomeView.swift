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
    @State private var currentlyShownTrendingIDs: Set<String> = []
    private let fallbackTrendingCoordinate = CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)
    private let utmCoordinate = CLLocationCoordinate2D(latitude: 43.5483, longitude: -79.6627)
    private let recentTrendingStorageKey = "sq_recent_trending_place_ids"

    private struct TrendingItem: Identifiable {
        let id: String
        var placeID: String?
        let title: String
        let subtitle: String
        let distanceText: String
        var photoURL: URL?
        var photoImage: UIImage?
        var detailDescription: String?
        var isExpanded: Bool = false
        var isLoadingDetails: Bool = false
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
                VStack(alignment: .leading, spacing: 0) {
                    homeHeroHeader

                    VStack(alignment: .leading, spacing: 0) {
                        NavigationLink {
                            ModeSelectionView(destination: .routeSetup)
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Start a Route")
                                        .font(.system(size: 17, weight: .bold, design: .serif))
                                        .foregroundStyle(Theme.text)
                                    Text("Choose a mode and explore your city")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(Theme.text.opacity(0.62))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Theme.text.opacity(0.38))
                            }
                            .padding(.vertical, 18)
                        }
                        .buttonStyle(.plain)

                        editorialSectionHeader(title: "Trending near you", actionTitle: "See all") {
                            ModeSelectionView()
                        }
                        .padding(.top, 2)

                        if isLoadingTrending && trendingPlaces.isEmpty {
                            HStack(spacing: 10) {
                                ProgressView().tint(Theme.terracotta)
                                Text("Finding popular places close to you...")
                                    .font(ThemeFont.caption)
                                    .foregroundStyle(Theme.text.opacity(0.65))
                            }
                            .padding(.vertical, 12)
                        } else if trendingPlaces.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(emptyTrendingMessage)
                                    .font(ThemeFont.caption)
                                    .foregroundStyle(Theme.text.opacity(0.65))
                                if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                                    Button("Open Location Settings", action: openAppSettings)
                                        .font(ThemeFont.caption)
                                        .foregroundStyle(Theme.terracotta)
                                }
                            }
                            .padding(.vertical, 12)
                        } else {
                            let items = Array(trendingPlaces.prefix(5))
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                    trendingMasonryCard(item: item, index: index)
                                }
                                if let challenge = SeedData.sampleChallenges().first {
                                    challengeCard(challenge: challenge)
                                }
                            }
                            .padding(.top, 8)
                        }

                        editorialSectionHeader(title: "Weekly leaderboard", actionTitle: "View all") {
                            LeaderboardsView()
                        }
                        .padding(.top, 20)

                        weeklyLeaderboardCard
                            .padding(.top, 6)
                            .padding(.bottom, 8)
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            waitBeganAt = Date()
            locationManager.requestPermission()
            locationManager.startUpdates()
            if let existingLocation = locationManager.location {
                Task { await loadTrendingNearby(from: existingLocation.coordinate) }
            } else if let lastKnown = locationManager.lastKnownCoordinate {
                Task { await loadTrendingNearby(from: lastKnown) }
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
                if let existingLocation = locationManager.location {
                    Task { await loadTrendingNearby(from: existingLocation.coordinate) }
                } else if let lastKnown = locationManager.lastKnownCoordinate {
                    Task { await loadTrendingNearby(from: lastKnown) }
                }
            }
        }
        .onReceive(locationManager.$lastKnownCoordinate.compactMap { $0 }) { coordinate in
            let shouldRefresh = !hasLoadedTrending || trendingPlaces.isEmpty
            guard shouldRefresh else { return }
            Task { await loadTrendingNearby(from: coordinate) }
        }
    }

    private var homeHeroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            Image("train")
                .resizable()
                .scaledToFill()
                .frame(height: 204)
                .frame(maxWidth: .infinity)
                .clipped()

            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Theme.bg.opacity(0.88), Theme.bg.opacity(0.62), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 68)

                Spacer(minLength: 0)

                LinearGradient(
                    colors: [.clear, Theme.bg.opacity(0.80), Theme.bg.opacity(0.98)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 132)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(greetingText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 1)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(app.user.displayName)
                        .font(.system(size: 30, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.55), radius: 5, x: 0, y: 1)
                    Text("· explorer")
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundStyle(.white.opacity(0.95))
                        .italic()
                        .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 1)
                }

                HStack(spacing: 10) {
                    statPill(icon: "trophy.fill", value: "\(app.user.points)", unit: "pts", tint: Theme.gold)
                    dividerPill
                    statPill(icon: "flame.fill", value: "\(app.user.streak)", unit: "day streak", tint: Theme.terracotta)
                    dividerPill
                    statPill(icon: "safari.fill", value: "\(app.user.routesCompleted)", unit: "routes", tint: Theme.sage)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.black.opacity(0.28))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .frame(height: 204)
    }

    private func statPill(icon: String, value: String, unit: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(unit)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
        }
    }

    private var dividerPill: some View {
        Rectangle()
            .fill(.white.opacity(0.24))
            .frame(width: 1, height: 12)
    }

    private func editorialSectionHeader<Destination: View>(
        title: String,
        actionTitle: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(Theme.terracotta)
                    .frame(width: 44, height: 3)
                    .clipShape(Capsule())
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.text)
            }
            Spacer()
            NavigationLink {
                destination()
            } label: {
                HStack(spacing: 3) {
                    Text(actionTitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(Theme.terracotta)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 6)
        }
    }

    private func trendingMasonryCard(item: TrendingItem, index: Int) -> some View {
        let tall = index % 3 != 1
        return Button {
            toggleTrendingExpansion(for: item.id)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    Group {
                        if let image = item.photoImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else if let photoURL = item.photoURL {
                            AsyncImage(url: photoURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                default:
                                    trendingPhotoPlaceholder
                                }
                            }
                        } else {
                            trendingPhotoPlaceholder
                        }
                    }
                    .clipped()

                    LinearGradient(
                        colors: [.black.opacity(0.62), .clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text(item.subtitle)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.74))
                            .lineLimit(1)
                    }
                    .padding(12)
                }
                .frame(maxWidth: .infinity)
                .frame(height: tall ? 208 : 140)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18))

                if item.isExpanded {
                    Divider().overlay(Theme.text.opacity(0.08))
                        .padding(.top, 8)
                    Group {
                        if item.isLoadingDetails {
                            HStack(spacing: 8) {
                                ProgressView().tint(Theme.terracotta)
                                Text("Loading details...")
                                    .font(ThemeFont.caption)
                                    .foregroundStyle(Theme.text.opacity(0.62))
                            }
                        } else {
                            Text(item.detailDescription ?? item.subtitle)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.text.opacity(0.75))
                                .lineLimit(4)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                }
            }
        }
        .buttonStyle(.plain)
    }


    private func challengeCard(challenge: Challenge) -> some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if UIImage(named: challengeBackgroundImageName(for: challenge)) != nil {
                    Image(challengeBackgroundImageName(for: challenge))
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Theme.text.opacity(0.09))
                }
            }
            .clipped()

            LinearGradient(
                colors: [.black.opacity(0.62), .clear],
                startPoint: .bottom,
                endPoint: .top
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text("CHALLENGE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.gold.opacity(0.92))
                .clipShape(Capsule())

                Text(challenge.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                    Text("\(challenge.rewardPoints) pts")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.82))
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 208)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func challengeBackgroundImageName(for challenge: Challenge) -> String {
        if challenge.title.localizedCaseInsensitiveContains("painted alley") {
            return "kyoto"
        }
        return "train"
    }

    private var greetingText: String {
        "WELCOME TO SIDEQUEST"
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
        let queryRadius = 15000

        // Temporary hard-priority path: show famous UTM-area places first.
        let prioritizedUTM = await utmFamousTrendingFallback(
            origin: coordinate,
            preferredMaxDistance: preferredDistance,
            fallbackMaxDistance: max(Double(queryRadius), 60_000)
        )
        if !prioritizedUTM.isEmpty {
            trendingPlaces = prioritizedUTM
            currentlyShownTrendingIDs = Set(trendingPlaces.compactMap(\.placeID))
            await preloadTrendingDetailsAndPhotos(limit: 5)
            return
        }

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
        async let viewpoints: [GoogleMapsService.PlaceResult] = {
            (try? await GoogleMapsService.shared.searchNearby(
                location: coordinate,
                radius: queryRadius,
                type: "tourist_attraction",
                keyword: "iconic viewpoint observation deck must see"
            )) ?? []
        }()
        async let famousFood: [GoogleMapsService.PlaceResult] = {
            (try? await GoogleMapsService.shared.searchNearby(
                location: coordinate,
                radius: queryRadius,
                type: "restaurant",
                keyword: "famous local favorite iconic"
            )) ?? []
        }()
        async let broadNearby: [GoogleMapsService.PlaceResult] = {
            (try? await GoogleMapsService.shared.searchNearby(
                location: coordinate,
                radius: queryRadius,
                type: nil,
                keyword: "popular local"
            )) ?? []
        }()

        var merged = await landmarks + culture + food + viewpoints + famousFood
        if merged.isEmpty {
            merged = await broadNearby
        }
        if !merged.isEmpty {
            let rankedFamous = rankFamousPlaces(merged, origin: coordinate, radiusMeters: Double(queryRadius))
            let photoEnriched = await enrichPlacesWithPhotoReferences(rankedFamous)
            let geminiCurated = await curateTrendingWithGemini(from: photoEnriched, userLocation: coordinate)
            let diversified = diversifyTrendingCandidates(geminiCurated)
            trendingPlaces = buildTrendingItems(
                from: diversified,
                origin: coordinate,
                preferredMaxDistance: preferredDistance,
                fallbackMaxDistance: Double(queryRadius),
                useInputOrdering: true
            )
            if !trendingPlaces.isEmpty {
                currentlyShownTrendingIDs = Set(trendingPlaces.compactMap(\.placeID))
                await preloadTrendingDetailsAndPhotos(limit: 5)
                return
            }
        }

        let utmFallback = await utmFamousTrendingFallback(
            origin: coordinate,
            preferredMaxDistance: preferredDistance,
            fallbackMaxDistance: Double(queryRadius)
        )
        if !utmFallback.isEmpty {
            trendingPlaces = utmFallback
            currentlyShownTrendingIDs = Set(trendingPlaces.compactMap(\.placeID))
            await preloadTrendingDetailsAndPhotos(limit: 5)
            return
        }

        let mapKitFallback = await mapKitTrendingFallback(
            from: coordinate,
            preferredMaxDistance: preferredDistance,
            fallbackMaxDistance: Double(queryRadius)
        )
        if !mapKitFallback.isEmpty {
            trendingPlaces = mapKitFallback
            currentlyShownTrendingIDs = Set(trendingPlaces.compactMap(\.placeID))
            await preloadTrendingDetailsAndPhotos(limit: 5)
            return
        }

        let manualUTM = await manualUTMTrendingFallback(from: coordinate)
        if !manualUTM.isEmpty {
            trendingPlaces = manualUTM
            currentlyShownTrendingIDs = Set(trendingPlaces.compactMap(\.placeID))
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
            trendingPlaces = cityFallback
            currentlyShownTrendingIDs = Set(trendingPlaces.compactMap(\.placeID))
            await preloadTrendingDetailsAndPhotos(limit: 5)
        } else {
            trendingPlaces = []
            currentlyShownTrendingIDs = Set(trendingPlaces.compactMap(\.placeID))
            await preloadTrendingDetailsAndPhotos(limit: 5)
        }
    }

    private func manualUTMTrendingFallback(from origin: CLLocationCoordinate2D) async -> [TrendingItem] {
        struct ManualUTMPlace {
            let title: String
            let subtitle: String
            let coordinate: CLLocationCoordinate2D
            let assetName: String?
        }

        let places: [ManualUTMPlace] = [
            .init(
                title: "University of Toronto Mississauga",
                subtitle: "Campus greens, trails, and iconic architecture",
                coordinate: CLLocationCoordinate2D(latitude: 43.5486, longitude: -79.6635),
                assetName: "utmsmaller"
            ),
            .init(
                title: "Erindale Park",
                subtitle: "River trails and scenic picnic spots",
                coordinate: CLLocationCoordinate2D(latitude: 43.5588, longitude: -79.6708),
                assetName: "erindale-park"
            ),
            .init(
                title: "Rattray Marsh Conservation Area",
                subtitle: "Waterfront boardwalk and nature views",
                coordinate: CLLocationCoordinate2D(latitude: 43.5178, longitude: -79.6260),
                assetName: "Rattray Marsh"
            ),
            .init(
                title: "Jack Darling Memorial Park",
                subtitle: "Lakefront skyline sunsets and trails",
                coordinate: CLLocationCoordinate2D(latitude: 43.5333, longitude: -79.6037),
                assetName: "jackdarlingsmall"
            ),
            .init(
                title: "Port Credit Lighthouse",
                subtitle: "Harbour landmark and marina views",
                coordinate: CLLocationCoordinate2D(latitude: 43.5479, longitude: -79.5839),
                assetName: "PortCredit"
            ),
            .init(
                title: "Kariya Park",
                subtitle: "Japanese-inspired city oasis",
                coordinate: CLLocationCoordinate2D(latitude: 43.5892, longitude: -79.6459),
                assetName: nil
            )
        ]

        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        var items = places.map { place in
            let distance = originLocation.distance(from: CLLocation(
                latitude: place.coordinate.latitude,
                longitude: place.coordinate.longitude
            ))
            return TrendingItem(
                id: "manual|\(place.title)|\(place.coordinate.latitude),\(place.coordinate.longitude)",
                placeID: nil,
                title: place.title,
                subtitle: place.subtitle,
                distanceText: distanceText(distance),
                photoURL: place.assetName == nil ? streetViewURL(for: place.coordinate) : nil,
                photoImage: place.assetName.flatMap { UIImage(named: $0) }
            )
        }

        for (index, place) in places.enumerated() {
            do {
                let nearby = try await GoogleMapsService.shared.searchNearby(
                    location: place.coordinate,
                    radius: 1200,
                    type: nil,
                    keyword: place.title
                )
                guard let match = nearby.first else { continue }

                let resolvedPlaceID = match.placeID.isEmpty ? nil : match.placeID
                var resolvedPhotoURL: URL? = nil
                if let photoRef = match.photos.first {
                    resolvedPhotoURL = GoogleMapsService.shared.photoURL(for: photoRef)
                } else if !match.placeID.isEmpty,
                          let details = try await GoogleMapsService.shared.placeDetails(placeID: match.placeID),
                          let photoRef = details.photoReferences.first {
                    resolvedPhotoURL = GoogleMapsService.shared.photoURL(for: photoRef)
                }

                if let resolvedPlaceID {
                    items[index].placeID = resolvedPlaceID
                }
                if let resolvedPhotoURL {
                    items[index].photoURL = resolvedPhotoURL
                }
            } catch {
                continue
            }
        }

        return items
    }

    private func streetViewURL(for coordinate: CLLocationCoordinate2D) -> URL? {
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/streetview")!
        components.queryItems = [
            URLQueryItem(name: "size", value: "800x500"),
            URLQueryItem(name: "location", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "fov", value: "90"),
            URLQueryItem(name: "pitch", value: "0"),
            URLQueryItem(name: "key", value: APIKeys.googleMaps)
        ]
        return components.url
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
                    placeID: nil,
                    title: item.name ?? "Nearby place",
                    subtitle: item.placemark.title ?? "Nearby",
                    distanceText: distanceText(distance),
                    photoURL: nil
                )
            }
    }

    private func utmFamousTrendingFallback(
        origin: CLLocationCoordinate2D,
        preferredMaxDistance: CLLocationDistance,
        fallbackMaxDistance: CLLocationDistance
    ) async -> [TrendingItem] {
        let utmRadius = 20_000
        async let attractions: [GoogleMapsService.PlaceResult] = {
            (try? await GoogleMapsService.shared.searchNearby(
                location: utmCoordinate,
                radius: utmRadius,
                type: "tourist_attraction",
                keyword: "famous iconic must see"
            )) ?? []
        }()
        async let museums: [GoogleMapsService.PlaceResult] = {
            (try? await GoogleMapsService.shared.searchNearby(
                location: utmCoordinate,
                radius: utmRadius,
                type: "museum",
                keyword: "popular"
            )) ?? []
        }()
        async let restaurants: [GoogleMapsService.PlaceResult] = {
            (try? await GoogleMapsService.shared.searchNearby(
                location: utmCoordinate,
                radius: utmRadius,
                type: "restaurant",
                keyword: "famous local favorite"
            )) ?? []
        }()
        async let cafes: [GoogleMapsService.PlaceResult] = {
            (try? await GoogleMapsService.shared.searchNearby(
                location: utmCoordinate,
                radius: utmRadius,
                type: "cafe",
                keyword: "popular scenic"
            )) ?? []
        }()

        let merged = await attractions + museums + restaurants + cafes
        guard !merged.isEmpty else { return [] }

        let ranked = rankFamousPlaces(merged, origin: utmCoordinate, radiusMeters: Double(utmRadius))
        let enriched = await enrichPlacesWithPhotoReferences(ranked)
        let curated = await curateTrendingWithGemini(from: enriched, userLocation: utmCoordinate)

        return buildTrendingItems(
            from: Array(curated.prefix(12)),
            origin: origin,
            preferredMaxDistance: preferredMaxDistance,
            fallbackMaxDistance: max(fallbackMaxDistance, 60_000),
            useInputOrdering: true
        )
    }

    private func buildTrendingItems(
        from places: [GoogleMapsService.PlaceResult],
        origin: CLLocationCoordinate2D,
        preferredMaxDistance: CLLocationDistance,
        fallbackMaxDistance: CLLocationDistance,
        useInputOrdering: Bool = false
    ) -> [TrendingItem] {
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)

        let deduped: [GoogleMapsService.PlaceResult]
        if useInputOrdering {
            var seen: Set<String> = []
            deduped = places.filter { place in
                let key = place.placeID.isEmpty ? "\(place.name)-\(place.coordinate.latitude)-\(place.coordinate.longitude)" : place.placeID
                if seen.contains(key) { return false }
                seen.insert(key)
                return true
            }
        } else {
            deduped = Dictionary(grouping: places, by: { $0.placeID.isEmpty ? "\($0.name)-\($0.coordinate.latitude)-\($0.coordinate.longitude)" : $0.placeID })
                .compactMap { $0.value.max(by: { $0.rating < $1.rating }) }
        }

        let rankedBase = deduped
            .compactMap { place -> (GoogleMapsService.PlaceResult, CLLocationDistance)? in
                let distance = originLocation.distance(from: CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude))
                guard distance <= fallbackMaxDistance else { return nil }
                return (place, distance)
            }
        let ranked: [(GoogleMapsService.PlaceResult, CLLocationDistance)]
        if useInputOrdering {
            ranked = rankedBase
        } else {
            ranked = rankedBase.sorted { lhs, rhs in
                let lhsScore = famousScore(for: lhs.0, distanceMeters: lhs.1)
                let rhsScore = famousScore(for: rhs.0, distanceMeters: rhs.1)
                if lhsScore == rhsScore { return lhs.1 < rhs.1 }
                return lhsScore > rhsScore
            }
        }
        let normalized = normalizeTrendingCandidates(
            ranked,
            preferredMaxDistance: preferredMaxDistance
        )

        return normalized.map { place, distance in
            TrendingItem(
                id: "\(place.placeID)|\(place.coordinate.latitude),\(place.coordinate.longitude)",
                placeID: place.placeID.isEmpty ? nil : place.placeID,
                title: place.name,
                subtitle: place.vicinity.isEmpty ? "Nearby" : place.vicinity,
                distanceText: distanceText(distance),
                photoURL: place.photoReference.flatMap { GoogleMapsService.shared.photoURL(for: $0) }
            )
        }
    }

    private func enrichPlacesWithPhotoReferences(
        _ places: [GoogleMapsService.PlaceResult],
        limit: Int = 24
    ) async -> [GoogleMapsService.PlaceResult] {
        guard !places.isEmpty else { return places }

        let candidates = Array(places.prefix(limit))
        var fetchedPhotoByPlaceID: [String: String] = [:]

        await withTaskGroup(of: (String, String?).self) { group in
            for place in candidates where place.photoReference == nil && !place.placeID.isEmpty {
                group.addTask {
                    do {
                        let details = try await GoogleMapsService.shared.placeDetails(placeID: place.placeID)
                        return (place.placeID, details?.photoReferences.first)
                    } catch {
                        return (place.placeID, nil)
                    }
                }
            }

            for await (placeID, photoRef) in group {
                if let photoRef, !photoRef.isEmpty {
                    fetchedPhotoByPlaceID[placeID] = photoRef
                }
            }
        }

        guard !fetchedPhotoByPlaceID.isEmpty else { return places }

        return places.map { place in
            guard place.photoReference == nil,
                  let fetched = fetchedPhotoByPlaceID[place.placeID] else {
                return place
            }

            return GoogleMapsService.PlaceResult(
                name: place.name,
                coordinate: place.coordinate,
                types: place.types,
                rating: place.rating,
                userRatingsTotal: place.userRatingsTotal,
                vicinity: place.vicinity,
                placeID: place.placeID,
                photos: [fetched]
            )
        }
    }

    private func rankFamousPlaces(
        _ places: [GoogleMapsService.PlaceResult],
        origin: CLLocationCoordinate2D,
        radiusMeters: CLLocationDistance
    ) -> [GoogleMapsService.PlaceResult] {
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let deduped = Dictionary(grouping: places, by: { place in
            place.placeID.isEmpty
                ? "\(place.name)-\(place.coordinate.latitude)-\(place.coordinate.longitude)"
                : place.placeID
        })
        .compactMap { $0.value.max(by: { $0.rating < $1.rating }) }

        return deduped
            .compactMap { place -> (GoogleMapsService.PlaceResult, CLLocationDistance)? in
                let distance = originLocation.distance(from: CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude))
                guard distance <= radiusMeters else { return nil }
                return (place, distance)
            }
            .sorted { lhs, rhs in
                let lhsScore = famousScore(for: lhs.0, distanceMeters: lhs.1)
                let rhsScore = famousScore(for: rhs.0, distanceMeters: rhs.1)
                if lhsScore == rhsScore { return lhs.1 < rhs.1 }
                return lhsScore > rhsScore
            }
            .map(\.0)
    }

    private func famousScore(
        for place: GoogleMapsService.PlaceResult,
        distanceMeters: CLLocationDistance
    ) -> Double {
        let ratingWeight = place.rating * 18.0
        let reviewsWeight = log10(Double(max(1, place.userRatingsTotal))) * 22.0
        let photoWeight = place.photoReference == nil ? 0.0 : 12.0
        let typeWeight: Double = {
            if place.types.contains("tourist_attraction") || place.types.contains("museum") { return 12 }
            if place.types.contains("restaurant") || place.types.contains("cafe") { return 8 }
            return 4
        }()
        let distancePenalty = min(distanceMeters / 1000.0, 18.0)
        return ratingWeight + reviewsWeight + photoWeight + typeWeight - distancePenalty
    }

    private func curateTrendingWithGemini(
        from places: [GoogleMapsService.PlaceResult],
        userLocation: CLLocationCoordinate2D
    ) async -> [GoogleMapsService.PlaceResult] {
        guard !places.isEmpty else { return [] }

        // Keep candidate count tight for quality and token usage.
        let candidates = Array(places.prefix(18))
        let placeHints: [String] = candidates.map { place in
            let typeHint = place.types.prefix(2).joined(separator: ", ")
            return "\(place.name) — \(place.vicinity). Types: \(typeHint). Rating: \(String(format: "%.1f", place.rating)). Reviews: \(place.userRatingsTotal)"
        }

        do {
            let curated = try await GeminiService().curateNearbyPlaces(
                mode: "Trending near you",
                userLocation: userLocation,
                placeHints: placeHints
            )

            let pickedIndices = curated.map(\.index)
            var ordered: [GoogleMapsService.PlaceResult] = pickedIndices.compactMap { index in
                guard index >= 0, index < candidates.count else { return nil }
                return candidates[index]
            }

            // Keep remaining candidates as deterministic fallback tail.
            let pickedSet = Set(pickedIndices)
            for (index, place) in candidates.enumerated() where !pickedSet.contains(index) {
                ordered.append(place)
            }
            return ordered
        } catch {
            return candidates
        }
    }

    private func diversifyTrendingCandidates(_ candidates: [GoogleMapsService.PlaceResult]) -> [GoogleMapsService.PlaceResult] {
        guard !candidates.isEmpty else { return [] }

        let recentIDs = Set(loadRecentTrendingIDs())
        let excluded = recentIDs.union(currentlyShownTrendingIDs)
        let unseen = candidates.filter { !excluded.contains(trendingPlaceKey(for: $0)) }
        let seen = candidates.filter { excluded.contains(trendingPlaceKey(for: $0)) }

        // Prioritize unseen places, then rotate/shuffle to keep feed fresh.
        var ordered = unseen.shuffled() + seen.shuffled()
        if ordered.count > 1 {
            let rotation = Int(Date().timeIntervalSince1970 / 3600) % ordered.count
            ordered = Array(ordered.dropFirst(rotation) + ordered.prefix(rotation))
        }

        // Persist recently shown places so the next loads avoid repeating.
        let shownKeys = Array(ordered.prefix(10)).map(trendingPlaceKey(for:))
        persistRecentTrendingIDs(shownKeys)

        return ordered
    }

    private func trendingPlaceKey(for place: GoogleMapsService.PlaceResult) -> String {
        place.placeID.isEmpty
            ? "\(place.name)|\(place.coordinate.latitude),\(place.coordinate.longitude)"
            : place.placeID
    }

    private func loadRecentTrendingIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: recentTrendingStorageKey) ?? []
    }

    private func persistRecentTrendingIDs(_ shown: [String]) {
        let existing = loadRecentTrendingIDs()
        let combined = shown + existing
        var unique: [String] = []
        var seen: Set<String> = []
        for id in combined where !id.isEmpty {
            if !seen.contains(id) {
                seen.insert(id)
                unique.append(id)
            }
            if unique.count >= 30 { break }
        }
        UserDefaults.standard.set(unique, forKey: recentTrendingStorageKey)
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

    @MainActor
    private func toggleTrendingExpansion(for itemID: String) {
        guard let tappedIndex = trendingPlaces.firstIndex(where: { $0.id == itemID }) else { return }
        let wasExpanded = trendingPlaces[tappedIndex].isExpanded

        for i in trendingPlaces.indices {
            trendingPlaces[i].isExpanded = false
        }

        guard !wasExpanded else { return }
        trendingPlaces[tappedIndex].isExpanded = true

        if trendingPlaces[tappedIndex].detailDescription == nil {
            let placeID = trendingPlaces[tappedIndex].placeID
            Task { await fetchTrendingDetails(for: itemID, placeID: placeID) }
        }
    }

    @MainActor
    private func fetchTrendingDetails(for itemID: String, placeID: String?) async {
        guard let index = trendingPlaces.firstIndex(where: { $0.id == itemID }) else { return }
        trendingPlaces[index].isLoadingDetails = true
        defer {
            if let latest = trendingPlaces.firstIndex(where: { $0.id == itemID }) {
                trendingPlaces[latest].isLoadingDetails = false
            }
        }

        guard let placeID, !placeID.isEmpty else {
            trendingPlaces[index].detailDescription = trendingPlaces[index].subtitle
            return
        }

        do {
            let details = try await GoogleMapsService.shared.placeEditorialDetails(placeID: placeID)
            if let latest = trendingPlaces.firstIndex(where: { $0.id == itemID }) {
                trendingPlaces[latest].detailDescription = details.description
                if trendingPlaces[latest].photoURL == nil {
                    trendingPlaces[latest].photoURL = details.photoURL
                }
            }
        } catch {
            if let latest = trendingPlaces.firstIndex(where: { $0.id == itemID }) {
                trendingPlaces[latest].detailDescription = trendingPlaces[latest].subtitle
            }
        }
    }

    @MainActor
    private func preloadTrendingDetailsAndPhotos(limit: Int) async {
        let targets = Array(trendingPlaces.prefix(limit))
        for target in targets {
            guard let placeID = target.placeID, !placeID.isEmpty else { continue }
            guard target.photoImage == nil || target.photoURL == nil || target.detailDescription == nil else { continue }

            do {
                let details = try await GoogleMapsService.shared.placeEditorialDetails(placeID: placeID)
                if let index = trendingPlaces.firstIndex(where: { $0.id == target.id }) {
                    if trendingPlaces[index].photoURL == nil {
                        trendingPlaces[index].photoURL = details.photoURL
                    }
                    if trendingPlaces[index].detailDescription == nil {
                        trendingPlaces[index].detailDescription = details.description
                    }
                }

                if let photoURL = details.photoURL,
                   let latest = trendingPlaces.firstIndex(where: { $0.id == target.id }),
                   trendingPlaces[latest].photoImage == nil,
                   let image = try? await GoogleMapsService.shared.fetchImage(url: photoURL) {
                    trendingPlaces[latest].photoImage = image
                }
            } catch {
                // Keep lightweight fallback content if details fail.
            }
        }

        // Prefer showing places that successfully resolved to a photo.
        let photoRich = trendingPlaces.filter { $0.photoImage != nil || $0.photoURL != nil }
        let withoutPhoto = trendingPlaces.filter { $0.photoImage == nil && $0.photoURL == nil }
        let reordered = photoRich + withoutPhoto
        if !reordered.isEmpty {
            trendingPlaces = reordered
        }
    }

    private var trendingPhotoPlaceholder: some View {
        ZStack {
            Rectangle()
                .fill(Theme.text.opacity(0.10))
            Image(systemName: "photo")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.text.opacity(0.30))
        }
    }

    private var emptyTrendingMessage: String {
        if let error = locationManager.locationErrorMessage, !error.isEmpty {
            return "Location error: \(error)"
        }

        if locationManager.location != nil || locationManager.lastKnownCoordinate != nil {
            return "Couldn't find enough famous nearby places right now. Pull to refresh in a moment."
        }

        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            return "Location is off for SideQuest. Enable it to see famous places near you."
        case .notDetermined:
            return "Allow location to see famous places near you."
        default:
            if Date().timeIntervalSince(waitBeganAt) > 8 {
                return "Still waiting for a GPS fix. Make sure precise location is enabled for SideQuest."
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
                    if entry.rank == 1 {
                        Image(systemName: "crown")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.gold)
                            .frame(width: 18, alignment: .leading)
                    } else {
                        Text("\(entry.rank)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.text.opacity(0.62))
                            .frame(width: 18, alignment: .leading)
                    }

                    Text(entry.initials)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text.opacity(0.72))
                        .frame(width: 30, height: 30)
                        .background(Theme.text.opacity(0.06))
                        .clipShape(Circle())

                    Text(entry.username)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text)

                    Spacer()

                    Text("\(entry.points) pts")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.text.opacity(0.65))
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 6)

                if index < weeklyLeaderboard.count - 1 {
                    Divider()
                    .overlay(Theme.text.opacity(0.08))
                }
            }

            Divider()
                .overlay(Theme.terracotta.opacity(0.18))

            HStack(spacing: 10) {
                Text("—")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.terracotta)
                    .frame(width: 18, alignment: .leading)

                Text(String(app.user.displayName.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.terracotta.opacity(0.85))
                    .frame(width: 30, height: 30)
                    .background(Theme.terracotta.opacity(0.10))
                    .clipShape(Circle())

                Text("You")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.terracotta)

                Spacer()

                Text("\(app.user.points) pts")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.terracotta)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
        }
    }
}

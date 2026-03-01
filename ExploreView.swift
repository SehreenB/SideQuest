import SwiftUI
import CoreLocation
import Combine
import MapKit

struct ExploreView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    @StateObject private var engine = DiscoveryEngine()
    @StateObject private var loc = LocationManager()

    @State private var selectedMode: NavigatorMode
    @State private var selectedTravelType: TravelType = .walking
    @State private var selectedDetourLevel: DetourLevel = .moderate
    @State private var selectedStopCount: Int = 3
    @State private var scenicTargetStop: DiscoveryEngine.DiscoveryStop?
    @State private var isGeneratingRoute = false
    @State private var generatedRoute: RoutePlan?
    @State private var showPreview = false
    @State private var errorText: String?
    private let fallbackSearchCoordinate = CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)

    init(initialMode: NavigatorMode = .adventure) {
        _selectedMode = State(initialValue: initialMode)
    }

    private var exploreMarkers: [MapMarker] {
        engine.suggestedStops.map { stop in
            MapMarker(
                title: stop.name,
                snippet: stop.desc,
                coordinate: stop.coordinate,
                color: .terracotta
            )
        }
    }

    private var mapCenter: CLLocationCoordinate2D {
        loc.location?.coordinate
            ?? loc.lastKnownCoordinate
            ?? fallbackSearchCoordinate
    }

    private let mapHeight: CGFloat = 320

    var body: some View {
        ZStack(alignment: .top) {
            Theme.bg.ignoresSafeArea()

            mapSection

            VStack(spacing: 0) {
                Color.clear
                    .frame(height: mapHeight - 16)
                contentSection
            }

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.9))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 14)
                .padding(.top, 10)
                Spacer()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            loc.requestPermission()
            loc.startUpdates()
            refreshPins()
        }
        .onReceive(loc.$location.compactMap { $0 }) { _ in
            refreshPins()
        }
        .onReceive(loc.$lastKnownCoordinate.compactMap { $0 }) { _ in
            if engine.suggestedStops.isEmpty {
                refreshPins()
            }
        }
        .onChange(of: loc.authorizationStatus) { _, _ in
            refreshPins()
        }
        .onChange(of: selectedMode) { _, _ in
            refreshPins()
        }
        .onChange(of: selectedTravelType) { _, _ in
            refreshPins()
        }
        .navigationDestination(isPresented: $showPreview) {
            if let generatedRoute {
                RoutePreviewView(route: generatedRoute)
            }
        }
        .sheet(item: $scenicTargetStop) { stop in
            scenicConfigSheet(for: stop)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
    }

    private var mapSection: some View {
        GoogleMapView(
            markers: exploreMarkers,
            polylinePath: [],
            showsUserLocation: true,
            center: mapCenter,
            zoom: 13,
            alwaysFitMarkersWhenNotFollowing: true
        )
        .frame(height: mapHeight)
        .clipped()
        .ignoresSafeArea(edges: .top)
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            modeChipRow

            Picker("Travel", selection: $selectedTravelType) {
                Text("Walking").tag(TravelType.walking)
                Text("Driving").tag(TravelType.driving)
            }
            .pickerStyle(.segmented)

            if let errorText {
                Text(errorText)
                    .font(ThemeFont.caption)
                    .foregroundStyle(.red)
            }

            if engine.isLoading && engine.suggestedStops.isEmpty {
                HStack {
                    ProgressView()
                        .tint(Theme.terracotta)
                    Text("Finding places near you...")
                        .font(ThemeFont.caption)
                        .foregroundStyle(Theme.text.opacity(0.7))
                }
                .padding(.top, 2)
            } else if engine.suggestedStops.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(emptyStateMessage)
                        .font(ThemeFont.caption)
                        .foregroundStyle(Theme.text.opacity(0.7))
                        .padding(.top, 2)

                    Button {
                        refreshPins()
                    } label: {
                        Text("Refresh Nearby")
                            .font(ThemeFont.caption)
                            .foregroundStyle(Theme.terracotta)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.65))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(engine.suggestedStops) { stop in
                            placeCard(stop: stop)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 0)
        .padding(.bottom, 8)
        .background(.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var modeChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(NavigatorMode.allCases) { mode in
                    modeChip(mode: mode, title: "\(emoji(for: mode)) \(mode.rawValue)")
                }
            }
        }
    }

    private func modeChip(mode: NavigatorMode, title: String) -> some View {
        let isSelected = selectedMode == mode
        return Button {
            selectedMode = mode
        } label: {
            Text(title)
                .font(ThemeFont.bodySmallStrong)
                .foregroundStyle(isSelected ? .white : Theme.text.opacity(0.75))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Theme.terracotta : Theme.text.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func detourChip(level: DetourLevel, title: String, minutes: Int) -> some View {
        let isSelected = selectedDetourLevel == level
        return Button {
            selectedDetourLevel = level
        } label: {
            VStack(spacing: 1) {
                Text(title)
                    .font(ThemeFont.bodySmallStrong)
                Text("~\(minutes) min")
                    .font(ThemeFont.micro)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : Theme.text.opacity(0.65))
            .background(isSelected ? Theme.terracotta : Theme.text.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func placeCard(stop: DiscoveryEngine.DiscoveryStop) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "mappin.circle")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(Theme.terracotta)
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 2) {
                    Text(stop.name)
                        .font(ThemeFont.bodyStrong)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(selectedMode.rawValue)
                        .font(ThemeFont.caption)
                        .foregroundStyle(Theme.text.opacity(0.65))
                    Text(stop.desc)
                        .font(ThemeFont.caption)
                        .foregroundStyle(Theme.text.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                Button {
                    Task { await goDirect(to: stop) }
                } label: {
                    Text("Go Direct")
                        .font(ThemeFont.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.sage)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    scenicTargetStop = stop
                } label: {
                    Text("Scenic Route")
                        .font(ThemeFont.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.terracotta)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(.white.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            if isGeneratingRoute {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.white.opacity(0.75))
                    .overlay {
                        ProgressView()
                            .tint(Theme.terracotta)
                    }
            }
        }
    }

    private func scenicConfigSheet(for stop: DiscoveryEngine.DiscoveryStop) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scenic Route Options")
                .font(ThemeFont.sectionTitle)
                .foregroundStyle(Theme.text)

            Text(stop.name)
                .font(ThemeFont.bodySmallStrong)
                .foregroundStyle(Theme.terracotta)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 6) {
                Text("DETOUR LEVEL")
                    .font(ThemeFont.caption)
                    .foregroundStyle(Theme.text.opacity(0.6))

                HStack(spacing: 8) {
                    detourChip(level: .light, title: "Light", minutes: detourImpactMinutes(for: .light))
                    detourChip(level: .moderate, title: "Moderate", minutes: detourImpactMinutes(for: .moderate))
                    detourChip(level: .bold, title: "Bold", minutes: detourImpactMinutes(for: .bold))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("STOPS: \(selectedStopCount)")
                    .font(ThemeFont.caption)
                    .foregroundStyle(Theme.text.opacity(0.6))

                Slider(
                    value: Binding(
                        get: { Double(selectedStopCount) },
                        set: { selectedStopCount = Int($0.rounded()) }
                    ),
                    in: 1...5,
                    step: 1
                )
                .tint(Theme.terracotta)
            }

            Button {
                Task {
                    scenicTargetStop = nil
                    await scenicRoute(to: stop)
                }
            } label: {
                Text("Start Scenic Route")
                    .font(ThemeFont.buttonSmall)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.terracotta)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Theme.bg)
    }

    @MainActor
    private func goDirect(to stop: DiscoveryEngine.DiscoveryStop) async {
        guard let origin = loc.location?.coordinate else {
            errorText = "Waiting for your current location."
            return
        }

        isGeneratingRoute = true
        errorText = nil
        defer { isGeneratingRoute = false }

        let destinationSpot = Spot(
            id: UUID(),
            name: stop.name,
            category: fallbackCategory(for: selectedMode),
            shortDescription: stop.desc,
            coordinate: stop.coordinate,
            modeTags: [selectedMode],
            travelTags: [selectedTravelType],
            googlePlaceID: nil
        )

        let mode = selectedTravelType == .walking ? "walking" : "driving"
        do {
            let directions = try await GoogleMapsService.shared.getDirections(
                origin: origin,
                destination: stop.coordinate,
                mode: mode
            )

            let minutes = max(1, directions.durationSeconds / 60)
            let route = RoutePlan(
                id: UUID(),
                mode: selectedMode,
                travelType: selectedTravelType,
                detour: .light,
                stopCount: 1,
                destinationName: stop.name,
                stops: [destinationSpot],
                estimatedMinutes: minutes,
                detourAddedMinutes: 0,
                estimatedPoints: 80,
                whyThisRoute: "Direct route to your selected destination.",
                routePolyline: directions.polylinePoints,
                fastestMinutes: minutes,
                navigationInstructions: directions.instructions
            )

            app.activeRoute = route
            generatedRoute = route
            showPreview = true
            return
        } catch {
        }

        let transport: MKDirectionsTransportType = selectedTravelType == .walking ? .walking : .automobile
        let polyline = await RouteBuilder.buildPolyline(stops: [origin, stop.coordinate], transport: transport)
        let fallbackPath = polyline.map(polylineCoordinates) ?? [origin, stop.coordinate]
        let fallbackMinutes = estimatedMinutes(from: origin, to: stop.coordinate, travel: selectedTravelType)

        let fallbackRoute = RoutePlan(
            id: UUID(),
            mode: selectedMode,
            travelType: selectedTravelType,
            detour: .light,
            stopCount: 1,
            destinationName: stop.name,
            stops: [destinationSpot],
            estimatedMinutes: fallbackMinutes,
            detourAddedMinutes: 0,
            estimatedPoints: 80,
            whyThisRoute: "Direct route to your selected destination.",
            routePolyline: fallbackPath,
            fastestMinutes: fallbackMinutes,
            navigationInstructions: []
        )

        app.activeRoute = fallbackRoute
        generatedRoute = fallbackRoute
        showPreview = true
    }

    @MainActor
    private func scenicRoute(to stop: DiscoveryEngine.DiscoveryStop) async {
        guard let origin = loc.location?.coordinate else {
            errorText = "Waiting for your current location."
            return
        }

        isGeneratingRoute = true
        errorText = nil
        defer { isGeneratingRoute = false }

        do {
            let destinationCandidate = ScenicRoutePlanner.DestinationCandidate(
                name: stop.name,
                subtitle: stop.desc,
                coordinate: stop.coordinate,
                placeID: nil
            )

            let scenic = try await ScenicRoutePlanner.shared.generateRoute(
                mode: selectedMode,
                travel: selectedTravelType,
                detour: selectedDetourLevel,
                desiredDurationMinutes: estimatedScenicDurationMinutes(
                    stops: selectedStopCount,
                    travel: selectedTravelType,
                    detour: selectedDetourLevel
                ),
                desiredStopCount: selectedStopCount,
                origin: origin,
                destinationQuery: nil,
                selectedCategoryDestination: destinationCandidate,
                selectedSearchPlaceID: nil
            )

            app.activeRoute = scenic
            generatedRoute = scenic
            showPreview = true
        } catch {
            errorText = "Unable to build scenic route right now."
        }
    }

    private func refreshPins() {
        let effectiveLocation = loc.location?.coordinate ?? loc.lastKnownCoordinate ?? fallbackSearchCoordinate
        guard abs(effectiveLocation.latitude) <= 90, abs(effectiveLocation.longitude) <= 180 else {
            loc.requestPermission()
            loc.startUpdates()
            return
        }
        Task {
            await engine.fetchNearbyPlaces(
                location: effectiveLocation,
                mode: selectedMode,
                travel: selectedTravelType
            )
        }
    }

    private var emptyStateMessage: String {
        switch loc.authorizationStatus {
        case .denied, .restricted:
            return "Location is off. Enable location access in Settings to see nearby places."
        case .notDetermined:
            return "Allow location access to load popular places near your area."
        default:
            if let locationError = loc.locationErrorMessage, !locationError.isEmpty {
                return "Location update issue: \(locationError)"
            }
            if let status = engine.statusMessage, !status.isEmpty {
                return status
            }
            return "Still searching nearby popular places. Try Refresh Nearby."
        }
    }

    private func emoji(for mode: NavigatorMode) -> String {
        switch mode {
        case .adventure: return "🧭"
        case .foodie: return "🍜"
        case .nature: return "🌿"
        case .culture: return "🎭"
        case .social: return "🤝"
        case .mystery: return "🔮"
        }
    }

    private func fallbackCategory(for mode: NavigatorMode) -> SpotCategory {
        switch mode {
        case .foodie: return .cafe
        case .nature: return .park
        case .culture: return .gallery
        case .adventure: return .viewpoint
        case .social: return .market
        case .mystery: return .viewpoint
        }
    }

    private func polylineCoordinates(_ polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: .init(), count: polyline.pointCount)
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: polyline.pointCount))
        return coords
    }

    private func estimatedMinutes(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, travel: TravelType) -> Int {
        let distance = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
            .distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
        let metersPerMinute: Double = travel == .walking ? 80 : 500
        return max(1, Int(distance / metersPerMinute))
    }

    private func estimatedScenicDurationMinutes(stops: Int, travel: TravelType, detour: DetourLevel) -> Int {
        let basePerStop: Int = travel == .walking ? 14 : 11
        let detourBonus = detourImpactMinutes(for: detour)
        return max(15, stops * basePerStop + detourBonus)
    }

    private func detourImpactMinutes(for level: DetourLevel) -> Int {
        switch (selectedTravelType, level) {
        case (.walking, .light): return 8
        case (.walking, .moderate): return 16
        case (.walking, .bold): return 24
        case (.driving, .light): return 6
        case (.driving, .moderate): return 12
        case (.driving, .bold): return 18
        }
    }
}

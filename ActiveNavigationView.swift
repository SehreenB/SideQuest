import SwiftUI
import CoreLocation
import Combine
import MapKit

struct ActiveNavigationView: View {
    @EnvironmentObject var app: AppState
    let route: RoutePlan

    @StateObject private var loc = LocationManager()

    @State private var routePolyline: [CLLocationCoordinate2D] = []
    @State private var remainingPolyline: [CLLocationCoordinate2D] = []
    @State private var liveInstructions: [NavigationInstruction] = []

    @State private var arrivedStopIDs: Set<UUID> = []
    @State private var instructionIndex: Int = 0

    @State private var distanceToNextStop: CLLocationDistance = .greatestFiniteMagnitude
    @State private var showMemorySheet = false
    @State private var showCompletionSheet = false
    @State private var routeCompleted = false

    @State private var isPlayingAudio = false
    @State private var isRerouting = false
    @State private var lastRerouteAt: Date = .distantPast
    @State private var lastAutoArrivedStopID: UUID?
    @State private var voiceGuidanceEnabled = true
    @State private var lastSpokenInstructionIndex: Int = -1

    private var userCoordinate: CLLocationCoordinate2D? {
        loc.location?.coordinate
    }

    private var userBearing: CLLocationDirection? {
        guard let course = loc.location?.course, course >= 0 else { return nil }
        return course
    }

    private var nextStop: Spot? {
        route.stops.first(where: { !arrivedStopIDs.contains($0.id) })
    }

    private var pendingStops: [Spot] {
        route.stops.filter { !arrivedStopIDs.contains($0.id) }
    }

    private var isNearStop: Bool {
        distanceToNextStop <= 80
    }

    private var autoArrivalThreshold: CLLocationDistance {
        route.travelType == .walking ? 35 : 55
    }

    private var instructionAdvanceThreshold: CLLocationDistance {
        route.travelType == .walking ? 20 : 35
    }

    private var instructionAnnouncementThreshold: CLLocationDistance {
        route.travelType == .walking ? 70 : 220
    }

    private var activeInstructions: [NavigationInstruction] {
        liveInstructions.isEmpty ? route.navigationInstructions : liveInstructions
    }

    private var currentInstruction: NavigationInstruction? {
        guard instructionIndex < activeInstructions.count else { return nil }
        return activeInstructions[instructionIndex]
    }

    private var mapMarkers: [MapMarker] {
        route.stops.enumerated().map { index, stop in
            let isArrived = arrivedStopIDs.contains(stop.id)
            return MapMarker(
                title: stop.name,
                snippet: isArrived ? "Checked in" : stop.shortDescription,
                coordinate: stop.coordinate,
                color: isArrived ? .gold : (index == route.stops.count - 1 ? .terracotta : .sage)
            )
        }
    }

    private var visiblePolyline: [CLLocationCoordinate2D] {
        remainingPolyline.isEmpty ? routePolyline : remainingPolyline
    }

    private var remainingDistanceMeters: CLLocationDistance {
        guard visiblePolyline.count > 1 else { return 0 }
        return zip(visiblePolyline, visiblePolyline.dropFirst()).reduce(0) { partial, segment in
            partial + CLLocation(latitude: segment.0.latitude, longitude: segment.0.longitude)
                .distance(from: CLLocation(latitude: segment.1.latitude, longitude: segment.1.longitude))
        }
    }

    private var remainingDistanceText: String {
        if remainingDistanceMeters >= 1000 {
            return String(format: "%.1f km", remainingDistanceMeters / 1000)
        }
        return "\(Int(remainingDistanceMeters)) m"
    }

    private var remainingEtaMinutes: Int {
        let metersPerMinute: Double = route.travelType == .walking ? 80 : 500
        return max(1, Int(remainingDistanceMeters / metersPerMinute))
    }

    private var nextStopDistanceText: String {
        guard distanceToNextStop.isFinite, distanceToNextStop < .greatestFiniteMagnitude else { return "--" }
        if distanceToNextStop >= 1000 {
            return String(format: "%.1f km", distanceToNextStop / 1000)
        }
        return "\(Int(distanceToNextStop)) m"
    }

    private var nextStopEtaMinutes: Int? {
        guard distanceToNextStop.isFinite, distanceToNextStop < .greatestFiniteMagnitude else { return nil }
        let metersPerMinute: Double = route.travelType == .walking ? 80 : 500
        return max(1, Int(distanceToNextStop / metersPerMinute))
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            GoogleMapView(
                markers: mapMarkers,
                polylinePath: visiblePolyline,
                showsUserLocation: true,
                center: route.stops.first?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                zoom: 16,
                userCoordinate: userCoordinate,
                userBearing: userBearing,
                followUser: true,
                showInitialOverviewBeforeFollow: true,
                forceRecenterToken: 0
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(isRerouting ? "Updating route..." : "Next instruction")
                            .font(ThemeFont.caption)
                            .foregroundStyle(Theme.text.opacity(0.78))
                        Spacer()
                        Button(role: .destructive) {
                            finishRoute()
                        } label: {
                            Text("End")
                                .font(ThemeFont.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                        }
                        .tint(.red)
                    }

                    Text(currentInstruction?.text ?? "Continue to destination")
                        .font(ThemeFont.bodyStrong)
                        .foregroundStyle(Theme.text)

                    HStack(spacing: 8) {
                        if let currentInstruction {
                            Text("In ~\(max(10, currentInstruction.distanceMeters)) m")
                                .font(ThemeFont.caption)
                                .foregroundStyle(Theme.terracotta)
                        }
                        Text("Remaining: \(remainingDistanceText)")
                            .font(ThemeFont.caption)
                            .foregroundStyle(Theme.text.opacity(0.72))
                        Text("ETA \(remainingEtaMinutes) min")
                            .font(ThemeFont.caption)
                            .foregroundStyle(Theme.text.opacity(0.72))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.white.opacity(0.88))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Spacer()

                VStack(spacing: 10) {
                    HStack {
                        Text(nextStop?.name ?? "Destination")
                            .font(ThemeFont.bodySmallStrong)
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(nextStopDistanceText)
                                .font(ThemeFont.caption)
                                .foregroundStyle(Theme.terracotta)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Text(nextStopEtaMinutes.map { "\($0) min" } ?? "--")
                                .font(ThemeFont.caption)
                                .foregroundStyle(Theme.text.opacity(0.75))
                                .lineLimit(1)
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            checkInAtCurrentStop()
                        } label: {
                            Text("Check In")
                                .font(ThemeFont.buttonSmall)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isNearStop ? Theme.sage : Theme.sage.opacity(0.25))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!isNearStop || nextStop == nil)

                        Button {
                            if nextStop != nil {
                                showMemorySheet = true
                            }
                        } label: {
                            Text("Capture")
                                .font(ThemeFont.buttonSmall)
                                .frame(width: 110)
                                .padding(.vertical, 12)
                                .background(.white.opacity(0.85))
                                .foregroundStyle(Theme.terracotta)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button {
                            Task { await toggleVoiceGuidance() }
                        } label: {
                            Image(systemName: voiceGuidanceEnabled ? "speaker.wave.2.fill" : "speaker.slash")
                                .font(.system(size: 18))
                                .foregroundStyle(Theme.gold)
                                .padding(10)
                                .background(Theme.gold.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(12)
                .background(.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 16))

            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .navigationTitle("Navigation")
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            loc.requestPermission()
            loc.startUpdates()
            Task { await prepareRouteGeometry() }
        }
        .onReceive(loc.$location.compactMap { $0 }) { location in
            updateProgress(with: location)
            Task { await rerouteIfNeeded(for: location) }
        }
        .onDisappear {
            loc.stopUpdates()
            ElevenLabsService.shared.stopPlayback()
        }
        .sheet(isPresented: $showMemorySheet) {
            if let nextStop {
                MemoryCaptureSheet(spot: nextStop)
            }
        }
        .sheet(isPresented: $showCompletionSheet) {
            RouteCompletionSheet(route: route)
        }
    }

    private func checkInAtCurrentStop() {
        guard let nextStop, isNearStop else { return }

        arrivedStopIDs.insert(nextStop.id)
        app.registerCheckIn(at: nextStop)

        if arrivedStopIDs.count >= route.stops.count {
            finishRoute()
        }
    }

    private func finishRoute() {
        guard !routeCompleted else { return }
        routeCompleted = true
        app.registerRouteCompletion(route)
        showCompletionSheet = true
        loc.stopUpdates()
    }

    private func updateProgress(with location: CLLocation) {
        guard !routeCompleted else { return }

        if let currentInstruction {
            let instructionDistanceMeters = instructionDistance(from: location, to: currentInstruction.coordinate)

            if voiceGuidanceEnabled,
               instructionDistanceMeters <= instructionAnnouncementThreshold,
               instructionIndex != lastSpokenInstructionIndex {
                lastSpokenInstructionIndex = instructionIndex
                Task {
                    await speakInstruction(currentInstruction.text)
                }
            }

            if instructionDistanceMeters < instructionAdvanceThreshold {
                instructionIndex += 1
            }
        }

        if let nextStop {
            distanceToNextStop = instructionDistance(from: location, to: nextStop.coordinate)
            if distanceToNextStop <= autoArrivalThreshold, lastAutoArrivedStopID != nextStop.id {
                lastAutoArrivedStopID = nextStop.id
                arrivedStopIDs.insert(nextStop.id)
                app.registerCheckIn(at: nextStop)
            }
        }

        if let destination = route.stops.last {
            let destinationDistance = instructionDistance(from: location, to: destination.coordinate)
            if destinationDistance < 30 {
                finishRoute()
            }
        }

        if arrivedStopIDs.count >= route.stops.count {
            finishRoute()
        }

        guard !routePolyline.isEmpty else { return }
        let nearest = nearestPolylineIndex(for: location.coordinate, in: routePolyline)
        if nearest < routePolyline.count {
            remainingPolyline = Array(routePolyline.suffix(from: nearest))
        }
    }

    private func rerouteIfNeeded(for location: CLLocation) async {
        guard !routeCompleted else { return }
        guard !routePolyline.isEmpty else { return }
        guard !pendingStops.isEmpty else { return }

        let nearest = nearestPolylineIndex(for: location.coordinate, in: routePolyline)
        guard nearest < routePolyline.count else { return }

        let nearestPoint = routePolyline[nearest]
        let distanceFromRoute = instructionDistance(from: location, to: nearestPoint)
        let threshold: CLLocationDistance = route.travelType == .walking ? 55 : 120

        guard distanceFromRoute > threshold else { return }
        guard Date().timeIntervalSince(lastRerouteAt) > 8 else { return }
        guard !isRerouting else { return }

        isRerouting = true
        defer {
            isRerouting = false
            lastRerouteAt = Date()
        }

        guard let destination = pendingStops.last?.coordinate else { return }
        let waypoints = Array(pendingStops.dropLast()).map(\.coordinate)
        let mode = route.travelType == .walking ? "walking" : "driving"

        do {
            let result = try await GoogleMapsService.shared.getDirections(
                origin: location.coordinate,
                destination: destination,
                waypoints: waypoints,
                mode: mode
            )
            if !result.polylinePoints.isEmpty {
                routePolyline = result.polylinePoints
                remainingPolyline = result.polylinePoints
                liveInstructions = result.instructions
                instructionIndex = 0
                return
            }
        } catch {
        }

        // Fallback reroute polyline using MapKit if Google reroute fails
        let legStops = [location.coordinate] + waypoints + [destination]
        if let polyline = await RouteBuilder.buildPolyline(
            stops: legStops,
            transport: route.travelType == .walking ? .walking : .automobile
        ) {
            routePolyline = polylineCoordinates(polyline)
            remainingPolyline = routePolyline
            instructionIndex = 0
        }
    }

    private func nearestPolylineIndex(for coordinate: CLLocationCoordinate2D, in path: [CLLocationCoordinate2D]) -> Int {
        var minDistance = CLLocationDistance.greatestFiniteMagnitude
        var minIndex = 0

        for (index, point) in path.enumerated() {
            let distance = instructionDistance(
                from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                to: point
            )
            if distance < minDistance {
                minDistance = distance
                minIndex = index
            }
        }

        return minIndex
    }

    private func instructionDistance(from location: CLLocation, to coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location.distance(from: target)
    }

    private func prepareRouteGeometry() async {
        if !route.routePolyline.isEmpty {
            routePolyline = route.routePolyline
            remainingPolyline = route.routePolyline
            liveInstructions = route.navigationInstructions
            return
        }

        guard let destination = route.stops.last?.coordinate else {
            return
        }

        let origin = loc.location?.coordinate ?? route.stops.first?.coordinate ?? destination
        let waypoints = Array(route.stops.dropLast()).map(\.coordinate)
        let mode = route.travelType == .walking ? "walking" : "driving"

        do {
            let result = try await GoogleMapsService.shared.getDirections(
                origin: origin,
                destination: destination,
                waypoints: waypoints,
                mode: mode
            )
            routePolyline = result.polylinePoints
            remainingPolyline = result.polylinePoints
            liveInstructions = result.instructions
            return
        } catch {
        }

        let legStops = [origin] + waypoints + [destination]
        if let polyline = await RouteBuilder.buildPolyline(
            stops: legStops,
            transport: route.travelType == .walking ? .walking : .automobile
        ) {
            routePolyline = polylineCoordinates(polyline)
            remainingPolyline = routePolyline
        } else {
            routePolyline = legStops
            remainingPolyline = legStops
        }
    }

    private func polylineCoordinates(_ polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: .init(), count: polyline.pointCount)
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: polyline.pointCount))
        return coords
    }

    private func toggleAudioGuide() async {
        await toggleVoiceGuidance()
    }

    private func toggleVoiceGuidance() async {
        voiceGuidanceEnabled.toggle()

        if !voiceGuidanceEnabled {
            ElevenLabsService.shared.stopPlayback()
            isPlayingAudio = false
            return
        }

        guard let instruction = currentInstruction else { return }
        await speakInstruction(instruction.text)
    }

    private func speakInstruction(_ text: String) async {
        guard voiceGuidanceEnabled else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !ElevenLabsService.shared.isPlaying else { return }

        isPlayingAudio = true
        do {
            try await ElevenLabsService.shared.playGuide(text: text)
        } catch {
            isPlayingAudio = false
        }
        isPlayingAudio = ElevenLabsService.shared.isPlaying
    }
}

import SwiftUI
import CoreLocation
import Combine

struct RouteSetupView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    @StateObject private var loc = LocationManager()

    @State private var destination: String = ""
    @State private var exploreAroundMe = false
    @State private var travel: TravelType = .walking
    @State private var detour: DetourLevel = .moderate
    @State private var desiredTripMinutes: Int = 45
    @State private var stopTarget: Int = 3

    @State private var customizeByMode: Bool
    @State private var selectedMode: NavigatorMode
    @State private var nearbyCategory: NavigatorMode
    @State private var nearbyRadiusMeters: Int = 3000

    @State private var categoryCandidates: [ScenicRoutePlanner.DestinationCandidate] = []
    @State private var selectedCandidateID: UUID?

    @State private var autocompletePredictions: [GoogleMapsService.AutocompletePrediction] = []
    @State private var selectedAutocompletePlaceID: String?

    @State private var generatedRoute: RoutePlan?
    @State private var showPreview = false
    @State private var isGenerating = false
    @State private var isLoadingAutocomplete = false
    @State private var errorText: String?

    init(initialMode: NavigatorMode? = nil, preferModeCustomization: Bool = false) {
        let mode = initialMode ?? .mystery
        _selectedMode = State(initialValue: mode)
        _nearbyCategory = State(initialValue: mode == .mystery ? .foodie : mode)
        _customizeByMode = State(initialValue: preferModeCustomization)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(ThemeFont.body)
                            .foregroundStyle(Theme.text.opacity(0.65))
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.terracotta)
                            .frame(height: 5)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.terracotta)
                            .frame(height: 5)
                    }
                    .padding(.top, 4)

                    Text("Set up your route")
                        .font(ThemeFont.pageTitle)
                        .foregroundStyle(Theme.text)

                    destinationBlock
                    travelBlock
                    detourBlock
                    tripLengthBlock
                    actionBlock
                }
                .padding(18)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            loc.requestPermission()
            loc.startUpdates()
            Task { await refreshCandidatesIfNeeded() }
            stopTarget = max(1, min(5, desiredTripMinutes / 15))
        }
        .onChange(of: exploreAroundMe) { _, _ in
            Task { await refreshCandidatesIfNeeded() }
        }
        .onChange(of: customizeByMode) { _, _ in
            Task { await refreshCandidatesIfNeeded() }
        }
        .onChange(of: selectedMode) { _, _ in
            Task { await refreshCandidatesIfNeeded() }
        }
        .onChange(of: nearbyCategory) { _, _ in
            Task { await refreshCandidatesIfNeeded() }
        }
        .onChange(of: nearbyRadiusMeters) { _, _ in
            Task { await refreshCandidatesIfNeeded() }
        }
        .onChange(of: destination) { _, newValue in
            guard !exploreAroundMe else { return }
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count < 2 {
                autocompletePredictions = []
                if trimmed.isEmpty { selectedAutocompletePlaceID = nil }
                return
            }
            if !autocompletePredictions.contains(where: { $0.fullText == trimmed }) {
                selectedAutocompletePlaceID = nil
            }
            Task { await fetchAutocomplete(query: trimmed) }
        }
        .onReceive(loc.$location.compactMap { $0 }) { _ in
            if exploreAroundMe {
                Task { await refreshCandidatesIfNeeded() }
            }
        }
        .navigationDestination(isPresented: $showPreview) {
            if let generatedRoute {
                RoutePreviewView(route: generatedRoute)
            }
        }
    }

    private var destinationBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DESTINATION")
                .font(ThemeFont.caption)
                .foregroundStyle(Theme.text.opacity(0.6))

            if exploreAroundMe {
                HStack(spacing: 8) {
                    Picker("Category", selection: $nearbyCategory) {
                        ForEach(NavigatorMode.allCases.filter { $0 != .mystery }) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Radius", selection: $nearbyRadiusMeters) {
                        Text("1 km").tag(1_000)
                        Text("3 km").tag(3_000)
                        Text("5 km").tag(5_000)
                    }
                    .pickerStyle(.menu)
                }

                ForEach(Array(categoryCandidates.prefix(2))) { candidate in
                    Button {
                        selectedCandidateID = candidate.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.name)
                                    .font(ThemeFont.caption)
                                    .foregroundStyle(Theme.text)
                                Text(candidate.subtitle)
                                    .font(ThemeFont.micro)
                                    .foregroundStyle(Theme.text.opacity(0.6))
                                    .lineLimit(1)
                            }
                            Spacer()
                            if selectedCandidateID == candidate.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.sage)
                            }
                        }
                        .padding(10)
                        .background(.white.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    exploreAroundMe = false
                } label: {
                    Label("Search by name/address", systemImage: "magnifyingglass")
                        .font(ThemeFont.bodyStrong)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(.white.opacity(0.55))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.text.opacity(0.5))
                    TextField("Where to?", text: $destination)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.white.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                ForEach(Array(autocompletePredictions.prefix(2))) { prediction in
                    Button {
                        destination = prediction.fullText
                        selectedAutocompletePlaceID = prediction.placeID.isEmpty ? nil : prediction.placeID
                        autocompletePredictions = []
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prediction.primaryText)
                                .font(ThemeFont.caption)
                            Text(prediction.secondaryText)
                                .font(ThemeFont.micro)
                                .foregroundStyle(Theme.text.opacity(0.65))
                                .lineLimit(1)
                        }
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(.white.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    exploreAroundMe = true
                } label: {
                    Label("Explore around me", systemImage: "mappin.and.ellipse")
                        .font(ThemeFont.bodyStrong)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(.white.opacity(0.55))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if isLoadingAutocomplete {
                ProgressView()
                    .tint(Theme.terracotta)
            }
        }
    }

    private var travelBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRAVEL TYPE")
                .font(ThemeFont.caption)
                .foregroundStyle(Theme.text.opacity(0.6))

            HStack(spacing: 12) {
                travelChip(type: .walking, icon: "figure.walk", title: "Walking")
                travelChip(type: .driving, icon: "car", title: "Driving")
            }
        }
    }

    private var detourBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DETOUR LEVEL")
                .font(ThemeFont.caption)
                .foregroundStyle(Theme.text.opacity(0.6))

            HStack(spacing: 8) {
                detourChip(level: .light, title: "Light", minutes: detourImpactMinutes(for: .light))
                detourChip(level: .moderate, title: "Moderate", minutes: detourImpactMinutes(for: .moderate))
                detourChip(level: .bold, title: "Bold", minutes: detourImpactMinutes(for: .bold))
            }
        }
    }

    private var tripLengthBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STOPS: \(stopTarget)")
                .font(ThemeFont.caption)
                .foregroundStyle(Theme.text.opacity(0.65))

            Slider(
                value: Binding(
                    get: { Double(stopTarget) },
                    set: {
                        stopTarget = Int($0.rounded())
                        desiredTripMinutes = estimatedMinutes(for: stopTarget, travel: travel)
                    }
                ),
                in: 1...5,
                step: 1
            )
            .tint(Theme.terracotta)

            HStack {
                ForEach(1...5, id: \.self) { value in
                    Text("\(value)")
                        .font(ThemeFont.caption)
                        .foregroundStyle(Theme.text.opacity(0.55))
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var actionBlock: some View {
        VStack(spacing: 6) {
            Button {
                Task { await generateRoute() }
            } label: {
                Text(isGenerating ? "Generating..." : "Preview Route")
                    .font(ThemeFont.button)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.terracotta)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .disabled(isGenerating || destinationQueryInvalid)

            if !hasCurrentLocation {
                Text("Waiting for GPS location...")
                    .font(ThemeFont.micro)
                    .foregroundStyle(Theme.text.opacity(0.65))
            }

            if let errorText {
                Text(errorText)
                    .font(ThemeFont.micro)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var modeForRoute: NavigatorMode {
        customizeByMode ? selectedMode : .mystery
    }

    private var selectedCandidate: ScenicRoutePlanner.DestinationCandidate? {
        categoryCandidates.first(where: { $0.id == selectedCandidateID })
    }

    private var hasCurrentLocation: Bool {
        loc.location != nil
    }

    private var destinationQueryInvalid: Bool {
        guard hasCurrentLocation else { return true }
        if exploreAroundMe { return selectedCandidate == nil }
        return destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func refreshCandidatesIfNeeded() async {
        guard exploreAroundMe else { return }
        guard let origin = loc.location?.coordinate else {
            await MainActor.run {
                categoryCandidates = []
                selectedCandidateID = nil
            }
            return
        }

        let candidates = await ScenicRoutePlanner.shared.destinationCandidates(
            near: origin,
            mode: nearbyCategory,
            radiusMeters: nearbyRadiusMeters
        )

        await MainActor.run {
            categoryCandidates = candidates
            selectedCandidateID = candidates.first?.id
        }
    }

    @MainActor
    private func fetchAutocomplete(query: String) async {
        isLoadingAutocomplete = true
        defer { isLoadingAutocomplete = false }

        do {
            // Destination search should not be constrained by nearby radius.
            let predictions = try await GoogleMapsService.shared.autocompletePlaces(input: query, location: nil)
            autocompletePredictions = predictions
        } catch {
            autocompletePredictions = []
            errorText = "Search suggestions unavailable right now."
        }
    }

    @MainActor
    private func generateRoute() async {
        isGenerating = true
        errorText = nil

        guard let origin = loc.location?.coordinate else {
            errorText = "Waiting for your current location. Please allow location access."
            isGenerating = false
            return
        }

        do {
            let route = try await ScenicRoutePlanner.shared.generateRoute(
                mode: exploreAroundMe ? nearbyCategory : modeForRoute,
                travel: travel,
                detour: detour,
                desiredDurationMinutes: desiredTripMinutes,
                desiredStopCount: stopTarget,
                origin: origin,
                destinationQuery: exploreAroundMe ? nil : destination,
                selectedCategoryDestination: exploreAroundMe ? selectedCandidate : nil,
                selectedSearchPlaceID: exploreAroundMe ? nil : selectedAutocompletePlaceID
            )

            app.activeRoute = route
            generatedRoute = route
            showPreview = true
        } catch {
            errorText = "Unable to generate route. Try another destination or nearby category."
        }

        isGenerating = false
    }

    private func travelChip(type: TravelType, icon: String, title: String) -> some View {
        let selected = travel == type
        return Button {
            travel = type
            desiredTripMinutes = estimatedMinutes(for: stopTarget, travel: travel)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                    .font(ThemeFont.bodyStrong)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(selected ? Theme.terracotta : Theme.text.opacity(0.78))
            .background(.white.opacity(0.65))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(selected ? Theme.terracotta : Theme.text.opacity(0.08), lineWidth: selected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private func detourChip(level: DetourLevel, title: String, minutes: Int) -> some View {
        let selected = detour == level
        return Button {
            detour = level
        } label: {
            VStack(spacing: 1) {
                Text(title)
                    .font(ThemeFont.bodySmallStrong)
                Text("~\(minutes) min")
                    .font(ThemeFont.micro)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(selected ? .white : Theme.text.opacity(0.62))
            .background(selected ? Theme.terracotta : Theme.text.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func estimatedMinutes(for stops: Int, travel: TravelType) -> Int {
        switch travel {
        case .walking:
            return max(15, stops * 15)
        case .driving:
            return max(15, stops * 12)
        }
    }

    private func detourImpactMinutes(for level: DetourLevel) -> Int {
        switch (travel, level) {
        case (.walking, .light): return 8
        case (.walking, .moderate): return 16
        case (.walking, .bold): return 24
        case (.driving, .light): return 6
        case (.driving, .moderate): return 12
        case (.driving, .bold): return 18
        }
    }
}

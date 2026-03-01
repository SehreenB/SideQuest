import SwiftUI
import CoreLocation

struct RoutePreviewView: View {
    @EnvironmentObject var app: AppState
    let route: RoutePlan

    @State private var polylineCoords: [CLLocationCoordinate2D] = []
    @State private var whyText: String?
    @State private var showActiveNavigation = false
    @State private var showSavedAlert = false
    @State private var showAdvanceBookingPrompt = false
    @State private var showAdvanceBookingSheet = false

    private var fastestMinutes: Int {
        route.fastestMinutes > 0 ? route.fastestMinutes : max(1, route.estimatedMinutes - route.detourAddedMinutes)
    }

    private var bookingCandidateStops: [Spot] {
        route.stops.filter(needsAdvanceBooking)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Rectangle()
                        .fill(Theme.terracotta)
                        .frame(width: 38, height: 3)
                        .clipShape(Capsule())
                        .padding(.top, 6)

                    Text("Route preview")
                        .font(.system(size: 30, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.text)

                    summaryRow

                    GoogleMapView.forRoute(
                        stops: route.stops,
                        polyline: polylineCoords,
                        showsUser: false
                    )
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(alignment: .topTrailing) {
                        Text("\(route.stops.count) stops")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.38))
                            .clipShape(Capsule())
                            .padding(10)
                    }
                    .onAppear {
                        polylineCoords = route.routePolyline.isEmpty ? route.stops.map(\.coordinate) : route.routePolyline

                        Task {
                            let gemini = GeminiService()
                            let names = route.stops.map { $0.name }
                            if let reason = try? await gemini.whyThisRoute(mode: route.mode.rawValue, stopNames: names) {
                                whyText = reason
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why this route")
                            .font(.system(size: 17, weight: .bold, design: .serif))
                            .foregroundStyle(Theme.text)
                        Text(whyText ?? route.whyThisRoute)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.text.opacity(0.76))
                    }
                    .padding(.vertical, 8)

                    HStack(alignment: .center) {
                        Text("Stops")
                            .font(.system(size: 17, weight: .bold, design: .serif))
                            .foregroundStyle(Theme.text)
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(Theme.gold)
                                .font(.system(size: 12))
                            Text("~\(route.estimatedPoints) points")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.gold)
                        }
                    }

                    ForEach(Array(route.stops.enumerated()), id: \.element.id) { index, stop in
                        NavigationLink {
                            StopDetailView(stop: stop, inRoute: true)
                        } label: {
                            stopRow(index: index + 1, stop: stop)
                        }
                        .buttonStyle(.plain)
                    }

                }
                .padding(18)
                .padding(.bottom, 88)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 14) {
                Button {
                    app.activeRoute = route
                    showSavedAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Save route")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Theme.text.opacity(0.72))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    if bookingCandidateStops.isEmpty {
                        startRouteNow()
                    } else {
                        showAdvanceBookingPrompt = true
                    }
                } label: {
                    HStack(spacing: 7) {
                        Text("Start route")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Theme.terracotta)
                    .underline(true, color: Theme.terracotta.opacity(0.72))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(Theme.bg.opacity(0.96))
        }
        .navigationDestination(isPresented: $showActiveNavigation) {
            ActiveNavigationView(route: route)
        }
        .alert("Route Saved", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your route has been saved and is ready to start.")
        }
        .confirmationDialog(
            "Book before you start?",
            isPresented: $showAdvanceBookingPrompt,
            titleVisibility: .visible
        ) {
            Button("Book in advance") {
                showAdvanceBookingSheet = true
            }
            Button("Start route anyway") {
                startRouteNow()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(advanceBookingMessage)
        }
        .sheet(isPresented: $showAdvanceBookingSheet) {
            AdvanceBookingSheet(
                stops: bookingCandidateStops,
                onSkip: {
                    showAdvanceBookingSheet = false
                    startRouteNow()
                },
                onDone: {
                    showAdvanceBookingSheet = false
                    startRouteNow()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 14) {
            Text(route.mode.rawValue.capitalized)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.text.opacity(0.65))
                .textCase(.uppercase)

            metricText(icon: "bolt.fill", value: "\(fastestMinutes) min", accent: Theme.text.opacity(0.72))
            metricText(icon: "sparkles", value: "\(route.estimatedMinutes) min", accent: Theme.terracotta)
            metricText(icon: "plus.circle", value: "+\(route.detourAddedMinutes) min", accent: Theme.sage)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 2)
    }

    private func metricText(icon: String, value: String, accent: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(accent)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)
        }
        .lineLimit(1)
    }

    private func stopRow(index: Int, stop: Spot) -> some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Theme.terracotta)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(stop.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(stop.category.rawValue.capitalized)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text.opacity(0.6))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.text.opacity(0.28))
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.text.opacity(0.08))
                .frame(height: 1)
                .padding(.leading, 40)
        }
    }

    private var advanceBookingMessage: String {
        guard let first = bookingCandidateStops.first else { return "Some stops may require advance booking." }
        if bookingCandidateStops.count == 1 {
            return "\"\(first.name)\" may require a reservation or ticket."
        }
        return "\(bookingCandidateStops.count) stops may require reservation or tickets."
    }

    private func startRouteNow() {
        app.activeRoute = route
        showActiveNavigation = true
    }

    private func needsAdvanceBooking(_ stop: Spot) -> Bool {
        switch stop.category {
        case .restaurant, .cafe, .gallery:
            return true
        case .mural, .park, .viewpoint, .bookstore, .market, .patio:
            break
        }

        let text = "\(stop.name) \(stop.shortDescription)".lowercased()
        let bookingKeywords = ["ticket", "tickets", "reservation", "reserve", "book", "entry", "admission", "museum", "show", "table"]
        return bookingKeywords.contains { text.contains($0) }
    }
}

private struct AdvanceBookingSheet: View {
    let stops: [Spot]
    let onSkip: () -> Void
    let onDone: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var callingStopID: UUID?
    @State private var callReferenceByStop: [UUID: String] = [:]
    @State private var callErrorText: String?
    @State private var userName: String = ""
    @State private var partySize: Int = 2
    @State private var preferredDate: Date = Date()
    @State private var preferredTime: Date = Date().addingTimeInterval(60 * 60)
    @State private var specialRequests: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("These stops may require booking in advance.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.text.opacity(0.7))

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Booking details")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.text.opacity(0.8))

                            TextField("Your name", text: $userName)
                                .textInputAutocapitalization(.words)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(.white.opacity(0.55))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            HStack(spacing: 8) {
                                DatePicker("", selection: $preferredDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(.white.opacity(0.55))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                DatePicker("", selection: $preferredTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(.white.opacity(0.55))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            Stepper("Party size: \(partySize)", value: $partySize, in: 1...20)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.text.opacity(0.8))

                            TextField("Special requests (optional)", text: $specialRequests)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(.white.opacity(0.55))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(12)
                        .background(.white.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        ForEach(stops) { stop in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(stop.name)
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(Theme.text)
                                        Text(stop.shortDescription)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(Theme.text.opacity(0.64))
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    if callingStopID == stop.id {
                                        ProgressView()
                                            .tint(Theme.terracotta)
                                    }
                                }

                                HStack(spacing: 14) {
                                    Button("AI Call") {
                                        Task { await startBookingCall(for: stop) }
                                    }
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.terracotta)
                                    .disabled(callingStopID != nil || userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                    Button("Open") {
                                        openBookingURL(for: stop)
                                    }
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.text.opacity(0.72))
                                }

                                if let reference = callReferenceByStop[stop.id] {
                                    Text("AI call started • Ref \(reference)")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(Theme.sage)
                                }
                            }
                            .padding(.vertical, 10)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(Theme.text.opacity(0.08))
                                    .frame(height: 1)
                            }
                        }
                    }
                    .padding(18)
                }

                if let callErrorText {
                    Text(callErrorText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 12) {
                    Button("Skip") { onSkip() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text.opacity(0.72))
                    Spacer()
                    Button("Done, start route") { onDone() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.terracotta)
                        .underline(true, color: Theme.terracotta.opacity(0.7))
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Theme.bg.opacity(0.95))
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Book in advance")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @MainActor
    private func startBookingCall(for stop: Spot) async {
        callErrorText = nil
        callingStopID = stop.id
        defer { callingStopID = nil }

        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            callErrorText = "Please enter your name before calling."
            return
        }

        guard let placeID = stop.googlePlaceID, !placeID.isEmpty else {
            callErrorText = "No place ID for \(stop.name). Use Open to book manually."
            return
        }

        do {
            guard let details = try await GoogleMapsService.shared.placeDetails(placeID: placeID) else {
                callErrorText = "Couldn’t load place details for \(stop.name)."
                return
            }

            guard let phone = details.internationalPhoneNumber ?? details.formattedPhoneNumber, !phone.isEmpty else {
                callErrorText = "\(stop.name) has no phone number available. Use Open to book manually."
                return
            }

            let bookingType = bookingTypeFor(stop: stop, placeTypes: details.types)
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            let response = try await RetellBookingService.shared.initiateBookingCall(
                venueName: details.name,
                venuePhoneNumber: phone,
                bookingType: bookingType,
                userName: trimmedName,
                partySize: partySize,
                preferredDate: dateFormatter.string(from: preferredDate),
                preferredTime: timeFormatter.string(from: preferredTime),
                specialRequests: specialRequests,
                numberOfTickets: bookingType == "event_ticket" ? max(1, partySize) : nil
            )
            callReferenceByStop[stop.id] = String(response.callId.prefix(10))
        } catch {
            callErrorText = error.localizedDescription
        }
    }

    private func bookingTypeFor(stop: Spot, placeTypes: [String]) -> String {
        if placeTypes.contains("restaurant") || placeTypes.contains("cafe") || stop.category == .restaurant || stop.category == .cafe {
            return "restaurant_reservation"
        }
        if placeTypes.contains("museum") || placeTypes.contains("tourist_attraction") || stop.category == .gallery {
            return "event_ticket"
        }
        return "activity_booking"
    }

    private func openBookingURL(for stop: Spot) {
        if let placeID = stop.googlePlaceID, !placeID.isEmpty,
           let url = URL(string: "https://www.google.com/maps/search/?api=1&query_place_id=\(placeID)") {
            openURL(url)
            return
        }
        let query = stop.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? stop.name
        if let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(query)") {
            openURL(url)
        }
    }
}

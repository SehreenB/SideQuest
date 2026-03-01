import SwiftUI
import CoreLocation

struct RoutePreviewView: View {
    @EnvironmentObject var app: AppState
    let route: RoutePlan

    @State private var polylineCoords: [CLLocationCoordinate2D] = []
    @State private var whyText: String?
    @State private var showActiveNavigation = false

    private var fastestMinutes: Int {
        route.fastestMinutes > 0 ? route.fastestMinutes : max(1, route.estimatedMinutes - route.detourAddedMinutes)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 6) {
                        Label("Fastest: \(fastestMinutes) min", systemImage: "bolt")
                            .font(ThemeFont.caption)
                            .foregroundStyle(Theme.text.opacity(0.6))

                        Text("•")
                            .foregroundStyle(Theme.text.opacity(0.4))

                        Label("Scenic: \(route.estimatedMinutes) min", systemImage: "sparkles")
                            .font(ThemeFont.caption)
                            .foregroundStyle(Theme.terracotta)

                        Text("(+\(route.detourAddedMinutes))")
                            .font(ThemeFont.caption)
                            .foregroundStyle(Theme.sage)
                    }

                    GoogleMapView.forRoute(
                        stops: route.stops,
                        polyline: polylineCoords,
                        showsUser: false
                    )
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
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

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Why this route")
                            .font(ThemeFont.bodyStrong)
                            .foregroundStyle(Theme.text)
                        Text(whyText ?? route.whyThisRoute)
                            .font(ThemeFont.bodySmall)
                            .foregroundStyle(Theme.text.opacity(0.75))
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Theme.gold)
                            .font(.system(size: 14))
                        Text("~\(route.estimatedPoints) points")
                            .font(ThemeFont.bodySmallStrong)
                            .foregroundStyle(Theme.gold)
                    }

                    Text("Stops")
                        .font(ThemeFont.bodyStrong)
                        .foregroundStyle(Theme.text)

                    ForEach(Array(route.stops.enumerated()), id: \.element.id) { index, stop in
                        NavigationLink {
                            StopDetailView(stop: stop, inRoute: true)
                        } label: {
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(ThemeFont.caption)
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Theme.terracotta)
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(stop.name)
                                        .font(ThemeFont.bodyStrong)
                                        .foregroundStyle(Theme.text)
                                    Text(stop.category.rawValue.capitalized)
                                        .font(ThemeFont.caption)
                                        .foregroundStyle(Theme.text.opacity(0.6))
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.text.opacity(0.3))
                            }
                            .padding(12)
                            .background(.white.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }

                }
                .padding(18)
            }
        }
        .navigationTitle("Preview")
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Button {
                    app.activeRoute = route
                    showActiveNavigation = true
                } label: {
                    Text("Start Route")
                        .font(ThemeFont.buttonSmall)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.sage)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                Button {
                } label: {
                    Text("Save")
                        .font(ThemeFont.buttonSmall)
                        .frame(width: 96)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.6))
                        .foregroundStyle(Theme.terracotta)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
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
    }
}

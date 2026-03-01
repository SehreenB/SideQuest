import SwiftUI

enum ModeSelectionDestination {
    case exploreNearby
    case routeSetup
}

struct ModeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    let destination: ModeSelectionDestination
    @State private var selected: NavigatorMode? = nil

    init(destination: ModeSelectionDestination = .exploreNearby) {
        self.destination = destination
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    header(topInset: geo.safeAreaInsets.top)

                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle()
                            .fill(Theme.terracotta)
                            .frame(width: 42, height: 3)
                            .clipShape(Capsule())
                            .padding(.top, 12)

                        Text("Choose your mode")
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundStyle(Theme.text)
                            .padding(.top, 8)

                        Text("How do you want to explore today?")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.text.opacity(0.62))
                            .padding(.top, 2)

                        VStack(spacing: 0) {
                            ForEach(Array(NavigatorMode.allCases.enumerated()), id: \.element.id) { index, mode in
                                modeRow(mode: mode)

                                if index < NavigatorMode.allCases.count - 1 {
                                    Divider()
                                        .overlay(Theme.text.opacity(0.10))
                                        .padding(.leading, 56)
                                }
                            }
                        }
                        .padding(.top, 14)

                        Spacer(minLength: 14)

                        NavigationLink {
                            if let selected {
                                switch destination {
                                case .exploreNearby:
                                    ExploreView(initialMode: selected)
                                case .routeSetup:
                                    RouteSetupView(initialMode: selected, preferModeCustomization: true)
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text("Continue")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundStyle(selected == nil ? Theme.text.opacity(0.45) : Theme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white.opacity(selected == nil ? 0.35 : 0.62))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Theme.text.opacity(0.10), lineWidth: 1)
                            )
                        }
                        .disabled(selected == nil)
                        .buttonStyle(.plain)
                        .padding(.bottom, 10)
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func header(topInset: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Image("kyoto")
                .resizable()
                .scaledToFill()
                .frame(height: 168 + topInset)
                .frame(maxWidth: .infinity)
                .clipped()

            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Theme.bg.opacity(0.70), Theme.bg.opacity(0.34), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 42)

                Spacer(minLength: 0)

                LinearGradient(
                    colors: [.clear, Theme.bg.opacity(0.82), Theme.bg],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 96)
            }

            Button {
                dismiss()
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.28), radius: 4, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .padding(.top, topInset + 10)
            .padding(.leading, 14)
        }
        .frame(height: 168 + topInset)
        .ignoresSafeArea(edges: .top)
    }

    private func modeRow(mode: NavigatorMode) -> some View {
        Button {
            selected = mode
        } label: {
            HStack(spacing: 12) {
                Image(systemName: modeRowIcon(for: mode))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text.opacity(0.62))
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.55))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.rawValue)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.text)
                    Text(modeRowSubtitle(for: mode))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.text.opacity(0.62))
                        .lineLimit(2)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Theme.text.opacity(0.22), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    if selected == mode {
                        Circle()
                            .fill(Theme.terracotta)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func modeRowIcon(for mode: NavigatorMode) -> String {
        switch mode {
        case .adventure: return "safari"
        case .foodie: return "fork.knife"
        case .nature: return "leaf"
        case .culture: return "paintpalette"
        case .social: return "person.2"
        case .mystery: return "sparkles"
        }
    }

    private func modeRowSubtitle(for mode: NavigatorMode) -> String {
        switch mode {
        case .adventure: return "Urban exploration, rooftops, hidden passages"
        case .foodie: return "Cafes, street food, hole-in-the-wall gems"
        case .nature: return "Parks, trails, gardens, waterways"
        case .culture: return "Murals, galleries, historic landmarks"
        case .social: return "Markets, community spaces, live music"
        case .mystery: return "Random surprises, no spoilers"
        }
    }
}

import SwiftUI

enum ModeSelectionDestination {
    case exploreNearby
    case routeSetup
}

struct ModeSelectionView: View {
    let destination: ModeSelectionDestination
    @State private var selected: NavigatorMode? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    init(destination: ModeSelectionDestination = .exploreNearby) {
        self.destination = destination
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.terracotta)
                            .frame(height: 5)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.text.opacity(0.12))
                            .frame(height: 5)
                    }
                    .padding(.top, 4)

                    Text("Choose your mode")
                        .font(ThemeFont.pageTitle)
                        .foregroundStyle(Theme.text)

                    Text("How do you want to explore today?")
                        .font(ThemeFont.body)
                        .foregroundStyle(Theme.text.opacity(0.6))

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(NavigatorMode.allCases) { mode in
                            Button {
                                selected = mode
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 26))
                                        .foregroundStyle(selected == mode ? .white : Theme.terracotta)
                                    Text(mode.rawValue)
                                        .font(ThemeFont.bodyStrong)
                                        .foregroundStyle(selected == mode ? .white : Theme.text)
                                    Text(mode.subtitle)
                                        .font(ThemeFont.caption)
                                        .foregroundStyle(selected == mode ? .white.opacity(0.85) : Theme.text.opacity(0.6))
                                        .lineLimit(3)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
                                .padding(14)
                                .background(selected == mode ? Theme.terracotta : .white.opacity(0.65))
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            }
                            .buttonStyle(.plain)
                        }
                    }

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
                        HStack {
                            Text("Continue")
                                .font(ThemeFont.button)
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(Theme.text.opacity(selected == nil ? 0.45 : 0.95))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white.opacity(selected == nil ? 0.3 : 0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(selected == nil)
                    .buttonStyle(.plain)

                }
                .padding(18)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var app: AppState

    private var badgeNames: [String] {
        app.user.unlockedBadges.map(\.rawValue)
    }

    private var badgePreviewIcons: [String] {
        let defaults = ["👟", "🎨", "🌿", "☕", "🔥", "🔮"]
        if badgeNames.isEmpty { return defaults }
        return badgeNames.map(symbol(for:))
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text(String(app.user.displayName.prefix(1)).uppercased())
                            .font(ThemeFont.pageTitle)
                            .foregroundStyle(Theme.terracotta)
                            .frame(width: 84, height: 84)
                            .background(.white.opacity(0.55))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Explorer")
                                .font(ThemeFont.pageTitle)
                                .foregroundStyle(Theme.text)
                            Text("Guest Account")
                                .font(ThemeFont.body)
                                .foregroundStyle(Theme.text.opacity(0.6))
                        }
                    }

                    HStack(spacing: 10) {
                        stat(icon: "trophy", title: "Points", value: "\(app.user.points)", tint: Theme.gold)
                        stat(icon: "flame", title: "Streak", value: "\(app.user.streak)", tint: Theme.terracotta)
                        stat(icon: "map", title: "Routes", value: "\(app.user.routesCompleted)", tint: Theme.sage)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Badges")
                                .font(ThemeFont.sectionTitle)
                                .foregroundStyle(Theme.text)
                            Spacer()
                            NavigationLink("View all") {
                                BadgeCollectionView()
                            }
                            .font(ThemeFont.bodySmallStrong)
                            .foregroundStyle(Theme.terracotta)
                        }

                        HStack(spacing: 10) {
                            ForEach(Array(badgePreviewIcons.prefix(5)), id: \.self) { badgeIcon in
                                Text(badgeIcon)
                                    .font(.system(size: 24))
                                    .frame(width: 50, height: 50)
                                    .background(.white.opacity(0.62))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Theme.text.opacity(0.06), lineWidth: 1)
                                    )
                            }

                            if badgePreviewIcons.count > 5 {
                                Text("+\(badgePreviewIcons.count - 5)")
                                    .font(ThemeFont.bodyStrong)
                                    .foregroundStyle(Theme.text.opacity(0.65))
                                    .frame(width: 50, height: 50)
                                    .background(.white.opacity(0.62))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                    .padding(14)
                    .background(.white.opacity(0.56))
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Theme.text.opacity(0.08), lineWidth: 1)
                    )

                    NavigationLink { LeaderboardsView() } label: {
                        row("Leaderboards", icon: "chart.bar")
                    }
                    .buttonStyle(.plain)

                    NavigationLink { SettingsView() } label: {
                        row("Settings", icon: "gearshape")
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(icon: String, title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(tint)
            Text(value)
                .font(ThemeFont.button)
            Text(title)
                .font(ThemeFont.caption)
                .foregroundStyle(Theme.text.opacity(0.6))
        }
        .foregroundStyle(Theme.text)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func row(_ title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: W.w700))
                .foregroundStyle(Theme.text.opacity(0.6))
            Text(title)
                .font(ThemeFont.bodyStrong)
                .foregroundStyle(Theme.text)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.text.opacity(0.35))
        }
        .padding(16)
        .background(.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func symbol(for badge: String) -> String {
        switch badge.lowercased() {
        case let v where v.contains("first"): return "👟"
        case let v where v.contains("mural"): return "🎨"
        case let v where v.contains("park"): return "🌿"
        case let v where v.contains("cafe"): return "☕"
        case let v where v.contains("streak"): return "🔥"
        case let v where v.contains("mystery"): return "🔮"
        case let v where v.contains("neighborhood"): return "🧭"
        default: return "⭐"
        }
    }
}

import SwiftUI

struct BadgeCollectionView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private struct BadgeCardModel: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let iconSystemName: String
        let current: Int
        let goal: Int

        var progressText: String { "\(current)/\(goal)" }
        var progressRatio: CGFloat {
            guard goal > 0 else { return 0 }
            return min(1, CGFloat(current) / CGFloat(goal))
        }
    }

    private var badges: [BadgeCardModel] {
        let publicMemoryCount = app.memories.filter { $0.visibility == .public }.count
        return [
            BadgeCardModel(
                id: "first_steps",
                title: "First Steps",
                subtitle: "Complete your first route",
                iconSystemName: "figure.walk",
                current: min(app.user.routesCompleted, 1),
                goal: 1
            ),
            BadgeCardModel(
                id: "mural_hunter",
                title: "Mural Hunter",
                subtitle: "Visit 5 murals",
                iconSystemName: "paintpalette",
                current: keywordCount(["mural", "street art", "graffiti"], cap: 5),
                goal: 5
            ),
            BadgeCardModel(
                id: "park_wanderer",
                title: "Park Wanderer",
                subtitle: "Visit 3 parks",
                iconSystemName: "leaf",
                current: keywordCount(["park", "garden", "trail"], cap: 3),
                goal: 3
            ),
            BadgeCardModel(
                id: "foodie_explorer",
                title: "Foodie Explorer",
                subtitle: "Visit 3 cafes or restaurants",
                iconSystemName: "fork.knife",
                current: keywordCount(["cafe", "coffee", "restaurant", "food"], cap: 3),
                goal: 3
            ),
            BadgeCardModel(
                id: "week_warrior",
                title: "Week Warrior",
                subtitle: "Maintain a 7-day streak",
                iconSystemName: "flame",
                current: min(app.user.streak, 7),
                goal: 7
            ),
            BadgeCardModel(
                id: "mystery_maven",
                title: "Mystery Maven",
                subtitle: "Complete 3 mystery challenges",
                iconSystemName: "sparkles",
                current: mysteryProgress(),
                goal: 3
            ),
            BadgeCardModel(
                id: "memory_archivist",
                title: "Memory Archivist",
                subtitle: "Capture 10 memories",
                iconSystemName: "photo.stack",
                current: min(app.memories.count, 10),
                goal: 10
            ),
            BadgeCardModel(
                id: "public_icon",
                title: "Public Icon",
                subtitle: "Share 8 public memories",
                iconSystemName: "megaphone",
                current: min(publicMemoryCount, 8),
                goal: 8
            ),
            BadgeCardModel(
                id: "points_pioneer",
                title: "Points Pioneer",
                subtitle: "Reach 1000 total points",
                iconSystemName: "trophy",
                current: min(app.user.points, 1000),
                goal: 1000
            ),
            BadgeCardModel(
                id: "route_rookie",
                title: "Route Rookie",
                subtitle: "Complete your first route",
                iconSystemName: "map",
                current: min(app.user.routesCompleted, 1),
                goal: 1
            )
        ]
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(ThemeFont.body)
                    }
                    .foregroundStyle(Theme.text.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)

                Text("Badge Collection")
                    .font(ThemeFont.pageTitle)
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 8)

                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(badges) { badge in
                            badgeCard(badge)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func badgeCard(_ badge: BadgeCardModel) -> some View {
        let isComplete = badge.current >= badge.goal

        return VStack(spacing: 10) {
            Image(systemName: badge.iconSystemName)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.terracotta)
                .frame(height: 42)
                .opacity(isComplete ? 1 : 0.55)

            Text(badge.title)
                .font(ThemeFont.bodyStrong)
                .foregroundStyle(Theme.text.opacity(isComplete ? 1 : 0.62))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(badge.subtitle)
                .font(ThemeFont.caption)
                .foregroundStyle(Theme.text.opacity(0.45))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(minHeight: 32)

            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.text.opacity(0.10))
                        Capsule()
                            .fill(Theme.terracotta.opacity(isComplete ? 0.95 : 0.6))
                            .frame(width: geo.size.width * badge.progressRatio)
                    }
                }
                .frame(height: 7)

                Text(badge.progressText)
                    .font(ThemeFont.caption)
                    .foregroundStyle(Theme.text.opacity(0.38))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 190)
        .background(.white.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.text.opacity(0.06), lineWidth: 1)
        )
        .opacity(isComplete ? 1 : 0.82)
    }

    private func keywordCount(_ keywords: [String], cap: Int) -> Int {
        let count = app.memories.reduce(into: 0) { partial, memory in
            let text = "\(memory.caption) \(memory.tags.joined(separator: " "))".lowercased()
            if keywords.contains(where: { text.contains($0) }) {
                partial += 1
            }
        }
        return min(count, cap)
    }

    private func mysteryProgress() -> Int {
        let hasMysteryBadge = app.user.unlockedBadges.contains(.hiddenGemFinder)
        if hasMysteryBadge {
            return 3
        }
        return min(app.challenges.count, 3) == 0 ? 0 : 1
    }
}

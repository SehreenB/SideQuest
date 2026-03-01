import SwiftUI

struct ChallengesView: View {
    @EnvironmentObject var app: AppState

    private struct ChallengeTemplate: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let points: Int
        let icon: String
    }

    private var challengeTemplates: [ChallengeTemplate] {
        [
            .init(id: "first_steps", title: "First Steps", subtitle: "Complete your first discovery route", points: 50, icon: "location.north.line"),
            .init(id: "memory_keeper", title: "Memory Keeper", subtitle: "Capture 5 memories during routes", points: 75, icon: "camera"),
            .init(id: "local_foodie", title: "Local Foodie", subtitle: "Visit 3 cafes or restaurants", points: 100, icon: "fork.knife"),
            .init(id: "nature_walker", title: "Nature Walker", subtitle: "Complete a nature route with all stops", points: 100, icon: "leaf"),
            .init(id: "mystery_maven", title: "Mystery Maven", subtitle: "Claim 3 completed challenges", points: 120, icon: "sparkles")
        ]
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Challenges")
                        .font(ThemeFont.pageTitle)
                        .foregroundStyle(Theme.text)

                    Text("Earn points and badges by exploring")
                        .font(ThemeFont.body)
                        .foregroundStyle(Theme.text.opacity(0.6))

                    challengeCard(
                        id: "daily_explorer",
                        title: "Daily Challenge",
                        subtitle: "Explore a new neighborhood today",
                        points: 50,
                        icon: "flame"
                    )

                    Text("All Challenges")
                        .font(ThemeFont.sectionTitle)
                        .foregroundStyle(Theme.text)

                    ForEach(challengeTemplates) { ch in
                        challengeCard(id: ch.id, title: ch.title, subtitle: ch.subtitle, points: ch.points, icon: ch.icon)
                    }
                }
                .padding(18)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func challengeCard(id: String, title: String, subtitle: String, points: Int, icon: String) -> some View {
        let progress = app.challengeProgress(for: id)
        let isClaimed = app.claimedChallengeIDs.contains(id)

        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: W.w700))
                    .foregroundStyle(Theme.terracotta)
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(ThemeFont.bodyStrong)
                        .foregroundStyle(Theme.text)
                    Text(subtitle)
                        .font(ThemeFont.caption)
                        .foregroundStyle(Theme.text.opacity(0.62))
                        .lineLimit(2)
                }

                Spacer()

                Label("\(points)", systemImage: "star")
                    .font(ThemeFont.caption)
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.6))
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    let ratio = progress.target > 0 ? min(1, CGFloat(progress.current) / CGFloat(progress.target)) : 0
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.text.opacity(0.12))
                        Capsule()
                            .fill(Theme.terracotta.opacity(0.8))
                            .frame(width: geo.size.width * ratio)
                    }
                }
                .frame(height: 7)

                HStack {
                    Text("\(progress.current)/\(progress.target)")
                        .font(ThemeFont.caption)
                        .foregroundStyle(Theme.text.opacity(0.6))
                    Spacer()
                    if isClaimed {
                        Text("Claimed")
                            .font(ThemeFont.caption)
                            .foregroundStyle(Theme.sage)
                    } else if progress.isComplete {
                        Button("Claim +\(points)") {
                            app.claimChallenge(id: id, reward: points)
                        }
                        .font(ThemeFont.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.terracotta)
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                    } else {
                        Text("In progress")
                            .font(ThemeFont.caption)
                            .foregroundStyle(Theme.text.opacity(0.5))
                    }
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

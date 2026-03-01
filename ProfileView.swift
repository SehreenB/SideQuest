import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var app: AppState
    @State private var friendEmailInput: String = ""
    @State private var friendMessage: String?

    private var unlockedBadges: [BadgeID] {
        Array(app.user.unlockedBadges)
            .sorted { $0.rawValue < $1.rawValue }
    }

    private var badgePreview: [BadgeID] {
        Array(unlockedBadges.prefix(6))
    }

    private var totalChallenges: Int { 6 }
    private var completedChallenges: Int { app.claimedChallengeIDs.count }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Spacer()
                        .frame(height: 42)
                    profileHeader
                    quickStats
                    progressSection
                    friendsSection
                    badgesSection
                    linksSection
                }
                .padding(18)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var profileHeader: some View {
        VStack(alignment: .center, spacing: 8) {
            Text(String(app.user.displayName.prefix(1)).uppercased())
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(Theme.terracotta)
                .frame(width: 68, height: 68)
                .background(.white.opacity(0.55))
                .clipShape(Circle())

            Text(app.user.displayName)
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(Theme.text)
            Text("Explorer profile")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.text.opacity(0.60))
        }
        .frame(maxWidth: .infinity)
    }

    private var quickStats: some View {
        HStack(spacing: 18) {
            statMetric(title: "Points", value: "\(app.user.points)")
            statDivider
            statMetric(title: "Streak", value: "\(app.user.streak)")
            statDivider
            statMetric(title: "Routes", value: "\(app.user.routesCompleted)")
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity)
    }

    private func statMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 23, weight: .bold, design: .serif))
                .foregroundStyle(Theme.text)
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.text.opacity(0.58))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Theme.text.opacity(0.14))
            .frame(width: 1, height: 34)
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Progress")
            progressRow(
                title: "Routes completed",
                valueText: "\(app.user.routesCompleted)",
                progress: min(1, Double(app.user.routesCompleted) / 10.0)
            )
            progressRow(
                title: "Challenges claimed",
                valueText: "\(completedChallenges)/\(totalChallenges)",
                progress: totalChallenges == 0 ? 0 : min(1, Double(completedChallenges) / Double(totalChallenges))
            )
            progressRow(
                title: "Unlocked badges",
                valueText: "\(unlockedBadges.count)",
                progress: min(1, Double(unlockedBadges.count) / Double(BadgeID.allCases.count))
            )
        }
    }

    private func progressRow(title: String, valueText: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(valueText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text.opacity(0.65))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.text.opacity(0.10))
                    Capsule()
                        .fill(Theme.terracotta.opacity(0.75))
                        .frame(width: geo.size.width * CGFloat(max(0, min(1, progress))))
                }
            }
            .frame(height: 7)
        }
        .padding(.vertical, 4)
    }

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("Badges")
                Spacer()
                NavigationLink("View all") {
                    BadgeCollectionView()
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.terracotta)
            }

            if badgePreview.isEmpty {
                Text("No badges unlocked yet.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text.opacity(0.58))
            } else {
                HStack(spacing: 10) {
                    ForEach(badgePreview, id: \.self) { badge in
                        Text(String(badge.rawValue.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.terracotta)
                            .frame(width: 38, height: 38)
                            .background(.white.opacity(0.56))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Friends")

            if app.isSignedIn {
                if let signedInEmail = app.signedInEmail, !signedInEmail.isEmpty {
                    Text("Signed in as \(signedInEmail)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.text.opacity(0.58))
                }

                HStack(spacing: 8) {
                    TextField("Add friend by Gmail", text: $friendEmailInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.text)

                    Button("Add") {
                        let result = app.addFriend(email: friendEmailInput)
                        if let result {
                            friendMessage = result
                        } else {
                            friendMessage = "Friend added."
                            friendEmailInput = ""
                        }
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.terracotta)
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)

                if let friendMessage {
                    Text(friendMessage)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.text.opacity(0.62))
                }

                if app.friends.isEmpty {
                    Text("No friends added yet.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.text.opacity(0.58))
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(app.friends.enumerated()), id: \.offset) { index, email in
                            HStack {
                                Text(email)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.text)
                                Spacer()
                            }
                            .padding(.vertical, 10)

                            if index < app.friends.count - 1 {
                                Divider()
                                    .overlay(Theme.text.opacity(0.10))
                            }
                        }
                    }
                }
            } else {
                Text("Sign in with Google to add friends by email.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text.opacity(0.58))
            }
        }
    }

    private var linksSection: some View {
        VStack(spacing: 0) {
            NavigationLink {
                LeaderboardsView()
            } label: {
                linkRow("Leaderboards", icon: "chart.bar")
            }
            .buttonStyle(.plain)

            Divider()
                .overlay(Theme.text.opacity(0.10))
                .padding(.leading, 32)

            NavigationLink {
                SettingsView()
            } label: {
                linkRow("Settings", icon: "gearshape")
            }
            .buttonStyle(.plain)
        }
    }

    private func linkRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text.opacity(0.62))
                .frame(width: 20)
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.text)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.text.opacity(0.35))
        }
        .padding(.vertical, 14)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 22, weight: .bold, design: .serif))
            .foregroundStyle(Theme.text)
    }
}

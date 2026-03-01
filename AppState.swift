import SwiftUI   // MUST be SwiftUI (not just Foundation)
import Combine

@MainActor
final class AppState: ObservableObject {
    enum AppTab: Hashable {
        case home
        case explore
        case vault
        case challenges
        case profile
    }

    @Published var isFirstLaunch: Bool = true
    @Published var isSignedIn: Bool = false
    @Published var selectedTab: AppTab = .home

    @Published var user: UserProfile = .init(
        id: UUID(),
        displayName: "Guest",
        points: 0,
        streak: 0,
        routesCompleted: 0,
        unlockedBadges: [],
        defaultPublicPosting: false
    )

    @Published var activeRoute: RoutePlan?
    @Published var memories: [MemoryItem] = []
    @Published var challenges: [Challenge] = SeedData.sampleChallenges()
    @Published var claimedChallengeIDs: Set<String> = []
    @Published var visitedCategoryCounts: [SpotCategory: Int] = [:]
    @Published var completedNatureRoutes: Int = 0

    private var routeCompletionDates: [Date] = []
    private var lastStreakUpdateDate: Date?

    func completeOnboarding(signIn: Bool) {
        isFirstLaunch = false
        isSignedIn = signIn
    }

    // MARK: - Progress & Rewards

    func registerCheckIn(at spot: Spot) {
        PointsEngine.awardCheckIn(to: &user)
        visitedCategoryCounts[spot.category, default: 0] += 1
        refreshBadgeUnlocks()
    }

    func registerRouteCompletion(_ route: RoutePlan) {
        user.points += route.estimatedPoints
        PointsEngine.incrementRouteCompletion(to: &user)

        if route.mode == .nature, !route.stops.isEmpty {
            completedNatureRoutes += 1
        }

        routeCompletionDates.append(Date())
        updateDailyStreakIfNeeded()
        refreshBadgeUnlocks()
    }

    func saveMemory(_ memory: MemoryItem) {
        memories.append(memory)

        if memory.visibility == .public {
            PointsEngine.awardPublicMemory(to: &user)
        }

        refreshBadgeUnlocks()
    }

    func claimChallenge(id: String, reward: Int) {
        guard !claimedChallengeIDs.contains(id) else { return }
        guard challengeProgress(for: id).isComplete else { return }

        claimedChallengeIDs.insert(id)
        PointsEngine.awardChallengeCompletion(to: &user, reward: reward)

        let completedMysteryChallenge = id == "mystery_maven"
        PointsEngine.checkBadgeUnlocks(
            user: &user,
            memories: memories,
            routesCompleted: user.routesCompleted,
            completedChallenge: completedMysteryChallenge
        )
    }

    func challengeProgress(for id: String) -> (current: Int, target: Int, isComplete: Bool) {
        switch id {
        case "daily_explorer":
            let completedToday = routeCompletionDates.contains { Calendar.current.isDateInToday($0) } ? 1 : 0
            return (completedToday, 1, completedToday >= 1)
        case "first_steps":
            let current = min(user.routesCompleted, 1)
            return (current, 1, current >= 1)
        case "memory_keeper":
            let current = min(memories.count, 5)
            return (current, 5, current >= 5)
        case "local_foodie":
            let cafes = visitedCategoryCounts[.cafe, default: 0]
            let restaurants = visitedCategoryCounts[.restaurant, default: 0]
            let current = min(cafes + restaurants, 3)
            return (current, 3, current >= 3)
        case "nature_walker":
            let current = min(completedNatureRoutes, 1)
            return (current, 1, current >= 1)
        case "mystery_maven":
            let challengeCompletions = claimedChallengeIDs.count
            let current = min(challengeCompletions, 3)
            return (current, 3, current >= 3)
        default:
            return (0, 1, false)
        }
    }

    private func updateDailyStreakIfNeeded() {
        let calendar = Calendar.current
        let today = Date()

        guard let lastStreakUpdateDate else {
            user.streak = max(1, user.streak)
            self.lastStreakUpdateDate = today
            return
        }

        if calendar.isDate(lastStreakUpdateDate, inSameDayAs: today) {
            return
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           calendar.isDate(lastStreakUpdateDate, inSameDayAs: yesterday) {
            user.streak += 1
        } else {
            user.streak = 1
        }

        self.lastStreakUpdateDate = today
    }

    private func refreshBadgeUnlocks() {
        PointsEngine.checkBadgeUnlocks(
            user: &user,
            memories: memories,
            routesCompleted: user.routesCompleted
        )
    }
}

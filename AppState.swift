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
    @Published var signedInEmail: String? = nil
    @Published var friends: [String] = []

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
    private var persistedMemoryCaptureCount: Int = 0

    private let progressStorageKey = "sq_app_progress_v1"

    private struct PersistedProgress: Codable {
        let points: Int
        let streak: Int
        let routesCompleted: Int
        let unlockedBadges: [String]
        let claimedChallengeIDs: [String]
        let visitedCategoryCounts: [String: Int]
        let completedNatureRoutes: Int
        let routeCompletionTimestamps: [Double]
        let lastStreakUpdateTimestamp: Double?
        let memoryCaptureCount: Int
        let isSignedIn: Bool?
        let signedInEmail: String?
        let friends: [String]?
    }

    init() {
        loadPersistedProgress()
    }

    func completeOnboarding(signIn: Bool) {
        isFirstLaunch = false
        isSignedIn = signIn
        if !signIn {
            signedInEmail = nil
            friends = []
        }
        persistProgress()
    }

    func applySignedInProfile(name: String, email: String?) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            user.displayName = trimmedName
        }
        if let email {
            let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            signedInEmail = normalized.isEmpty ? nil : normalized
        }
        isSignedIn = true
        persistProgress()
    }

    @discardableResult
    func addFriend(email: String) -> String? {
        guard isSignedIn else { return "Sign in to add friends." }

        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return "Enter an email address." }
        guard isValidEmail(normalized) else { return "Enter a valid email." }

        if let own = signedInEmail, own == normalized {
            return "You cannot add your own email."
        }
        if friends.contains(normalized) {
            return "This friend is already added."
        }

        friends.insert(normalized, at: 0)
        persistProgress()
        return nil
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Progress & Rewards

    func registerCheckIn(at spot: Spot) {
        PointsEngine.awardCheckIn(to: &user)
        visitedCategoryCounts[spot.category, default: 0] += 1
        refreshBadgeUnlocks()
        persistProgress()
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
        persistProgress()
    }

    func saveMemory(_ memory: MemoryItem) {
        memories.append(memory)
        persistedMemoryCaptureCount += 1
        PointsEngine.awardMemory(to: &user, visibility: memory.visibility)
        refreshBadgeUnlocks()
        persistProgress()
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
        persistProgress()
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
            let current = min(max(memories.count, persistedMemoryCaptureCount), 5)
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
        persistProgress()
    }

    private func persistProgress() {
        let payload = PersistedProgress(
            points: user.points,
            streak: user.streak,
            routesCompleted: user.routesCompleted,
            unlockedBadges: user.unlockedBadges.map(\.rawValue),
            claimedChallengeIDs: Array(claimedChallengeIDs),
            visitedCategoryCounts: Dictionary(
                uniqueKeysWithValues: visitedCategoryCounts.map { ($0.key.rawValue, $0.value) }
            ),
            completedNatureRoutes: completedNatureRoutes,
            routeCompletionTimestamps: routeCompletionDates.map(\.timeIntervalSince1970),
            lastStreakUpdateTimestamp: lastStreakUpdateDate?.timeIntervalSince1970,
            memoryCaptureCount: persistedMemoryCaptureCount,
            isSignedIn: isSignedIn,
            signedInEmail: signedInEmail,
            friends: friends
        )

        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: progressStorageKey)
    }

    private func loadPersistedProgress() {
        guard let data = UserDefaults.standard.data(forKey: progressStorageKey),
              let payload = try? JSONDecoder().decode(PersistedProgress.self, from: data) else {
            return
        }

        user.points = payload.points
        user.streak = payload.streak
        user.routesCompleted = payload.routesCompleted
        user.unlockedBadges = Set(payload.unlockedBadges.compactMap(BadgeID.init(rawValue:)))
        claimedChallengeIDs = Set(payload.claimedChallengeIDs)
        visitedCategoryCounts = Dictionary(
            uniqueKeysWithValues: payload.visitedCategoryCounts.compactMap { key, value in
                guard let category = SpotCategory(rawValue: key) else { return nil }
                return (category, value)
            }
        )
        completedNatureRoutes = payload.completedNatureRoutes
        routeCompletionDates = payload.routeCompletionTimestamps.map(Date.init(timeIntervalSince1970:))
        if let ts = payload.lastStreakUpdateTimestamp {
            lastStreakUpdateDate = Date(timeIntervalSince1970: ts)
        }
        persistedMemoryCaptureCount = payload.memoryCaptureCount
        isSignedIn = payload.isSignedIn ?? isSignedIn
        signedInEmail = payload.signedInEmail
        friends = payload.friends ?? []
    }
}

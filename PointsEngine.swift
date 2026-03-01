import Foundation

enum PointsEngine {
    static func awardCheckIn(to user: inout UserProfile, base: Int = 80) {
        user.points += base
    }

    static func awardMemory(to user: inout UserProfile, visibility: MemoryVisibility) {
        // Public shares should reward more than private captures.
        switch visibility {
        case .public:
            user.points += 60
        case .friends:
            user.points += 40
        case .private:
            user.points += 25
        }
    }

    static func awardChallengeCompletion(to user: inout UserProfile, reward: Int) {
        user.points += reward
    }

    static func incrementRouteCompletion(to user: inout UserProfile) {
        user.routesCompleted += 1
    }

    static func updateStreak(to user: inout UserProfile) {
        // MVP: just increment streak on completion
        user.streak += 1
    }

    static func checkBadgeUnlocks(user: inout UserProfile, memories: [MemoryItem], routesCompleted: Int, completedChallenge: Bool = false) {
        if completedChallenge {
            user.unlockedBadges.insert(.hiddenGemFinder)
        }

        if routesCompleted >= 1 {
            user.unlockedBadges.insert(.routeRookie)
        }

        if routesCompleted >= 3 {
            user.unlockedBadges.insert(.neighborhoodNomad)
        }

        let publicPosts = memories.filter { $0.visibility == .public }.count
        if publicPosts >= 3 {
            user.unlockedBadges.insert(.communityCurator)
        }
        if publicPosts >= 8 {
            user.unlockedBadges.insert(.publicIcon)
        }

        if memories.count >= 10 {
            user.unlockedBadges.insert(.memoryArchivist)
        }

        let corpus = memories.map { "\($0.caption.lowercased()) \($0.tags.joined(separator: " ").lowercased())" }
        let muralVisits = corpus.filter { $0.contains("mural") || $0.contains("street art") || $0.contains("graffiti") }.count
        if muralVisits >= 5 {
            user.unlockedBadges.insert(.muralHunter)
        }

        let parkVisits = corpus.filter { $0.contains("park") || $0.contains("garden") || $0.contains("trail") }.count
        if parkVisits >= 5 {
            user.unlockedBadges.insert(.parkHopper)
        }

        let cafeVisits = corpus.filter { $0.contains("cafe") || $0.contains("coffee") || $0.contains("restaurant") || $0.contains("food") }.count
        if cafeVisits >= 5 {
            user.unlockedBadges.insert(.cafeCrawler)
        }

        if user.streak >= 7 {
            user.unlockedBadges.insert(.streakWalker)
        }

        if user.points >= 1000 {
            user.unlockedBadges.insert(.pointsPioneer)
        }
    }
}

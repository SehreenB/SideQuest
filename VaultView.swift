import SwiftUI

struct VaultView: View {
    @EnvironmentObject var app: AppState
    @State private var tab: MemoryVisibility = .private
    @State private var publicFeed: [CommunityMemory] = []
    @State private var isLoadingPublic = false

    private struct CommunityMemory: Identifiable {
        let id: String
        let caption: String
        let photoURL: String?
        let placeName: String
        let likes: Int
    }

    private var filteredMemories: [MemoryItem] {
        if tab == .private {
            return app.memories.filter { $0.visibility == .private || $0.visibility == .friends }
        }
        return app.memories.filter { $0.visibility == tab }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Text("Your Vault")
                    .font(ThemeFont.pageTitle)
                    .foregroundStyle(Theme.text)

                vaultTabRow
                vaultFriendsSection

                if tab == .private {
                    if filteredMemories.isEmpty {
                        Spacer()
                        VStack(spacing: 6) {
                            Text("No memories yet")
                                .font(ThemeFont.bodyStrong)
                                .foregroundStyle(Theme.text.opacity(0.55))
                            Text("Start a route to capture your first!")
                                .font(ThemeFont.body)
                                .foregroundStyle(Theme.text.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                ForEach(Array(filteredMemories.enumerated()), id: \.element.id) { index, memory in
                                    privateMemoryRow(memory)
                                    if index < filteredMemories.count - 1 {
                                        Divider()
                                            .overlay(Theme.text.opacity(0.10))
                                            .padding(.leading, 2)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    if isLoadingPublic && publicFeed.isEmpty {
                        Spacer()
                        HStack {
                            ProgressView()
                                .tint(Theme.terracotta)
                            Text("Loading public memories...")
                                .font(ThemeFont.caption)
                                .foregroundStyle(Theme.text.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        Spacer()
                    } else if publicFeed.isEmpty {
                        Spacer()
                        VStack(spacing: 6) {
                            Text("No public memories yet")
                                .font(ThemeFont.bodyStrong)
                                .foregroundStyle(Theme.text.opacity(0.55))
                            Text("Share a memory as public to see it here.")
                                .font(ThemeFont.body)
                                .foregroundStyle(Theme.text.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                ForEach(Array(publicFeed.enumerated()), id: \.element.id) { index, memory in
                                    publicMemoryRow(memory)
                                    if index < publicFeed.count - 1 {
                                        Divider()
                                            .overlay(Theme.text.opacity(0.10))
                                            .padding(.leading, 2)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(18)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if tab == .public {
                Task { await loadPublicFeed() }
            }
        }
        .onChange(of: tab) { _, newValue in
            if newValue == .public {
                Task { await loadPublicFeed() }
            }
        }
    }

    private var vaultFriendsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Friends")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.text)
                Spacer()
                if !app.isSignedIn {
                    Text("Sign in required")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.text.opacity(0.5))
                }
            }

            if app.isSignedIn {
                if app.friends.isEmpty {
                    Text("No friends added yet. Add friends from your profile.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.text.opacity(0.58))
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(app.friends.prefix(8).enumerated()), id: \.offset) { _, email in
                                Text(email)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.sage)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Theme.sage.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            } else {
                Text("Sign in with Google to connect with friends.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text.opacity(0.58))
            }
        }
        .padding(.top, 2)
    }

    private var vaultTabRow: some View {
        HStack(spacing: 14) {
            vaultTabButton(.private, title: "Private", symbol: "lock")
            Text("•")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.text.opacity(0.25))
            vaultTabButton(.public, title: "Public", symbol: "globe")
        }
        .padding(.vertical, 2)
    }

    private func vaultTabButton(_ visibility: MemoryVisibility, title: String, symbol: String) -> some View {
        let isSelected = tab == visibility
        return Button {
            tab = visibility
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isSelected ? Theme.terracotta : Theme.text.opacity(0.62))
        }
        .buttonStyle(.plain)
    }

    private func privateMemoryRow(_ memory: MemoryItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(memory.caption)
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.text)
                .lineLimit(2)
            Text(memory.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.text.opacity(0.58))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
    }

    private func publicMemoryRow(_ memory: CommunityMemory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.text.opacity(0.08))
                    .frame(height: 154)

                if let photoURL = memory.photoURL, let url = URL(string: photoURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .tint(Theme.terracotta)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 154)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        case .failure:
                            Image(systemName: "mappin")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Theme.text.opacity(0.45))
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "mappin")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.text.opacity(0.45))
                }
            }

            Text(memory.caption)
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.text)
                .lineLimit(2)

            HStack {
                Label(memory.placeName, systemImage: "mappin")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.sage)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "heart")
                    Text("\(memory.likes)")
                }
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.text.opacity(0.6))
            }
        }
        .padding(.vertical, 14)
    }

    @MainActor
    private func loadPublicFeed() async {
        isLoadingPublic = true
        defer { isLoadingPublic = false }

        _ = await APIService.shared.promoteExistingPhotoMemoriesToPublic()
        let rows = await APIService.shared.fetchPublicMemories()
        publicFeed = rows.compactMap { row in
            let idValue = (row["id"] as? String) ?? UUID().uuidString
            let caption = (row["caption"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let photoURL = (row["photo_url"] as? String) ?? (row["photoURL"] as? String) ?? (row["image_url"] as? String)
            let placeName =
                (row["place_name"] as? String) ??
                (row["spot_name"] as? String) ??
                (row["location_name"] as? String) ??
                (row["vicinity"] as? String) ??
                "Nearby place"

            let likes =
                (row["likes"] as? Int) ??
                Int((row["likes"] as? String) ?? "") ??
                (row["like_count"] as? Int) ??
                0

            return CommunityMemory(
                id: idValue,
                caption: (caption?.isEmpty == false ? caption! : "Shared memory"),
                photoURL: photoURL,
                placeName: placeName,
                likes: likes
            )
        }
    }
}

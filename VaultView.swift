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
        app.memories.filter { $0.visibility == tab }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Text("Your Vault")
                    .font(ThemeFont.pageTitle)
                    .foregroundStyle(Theme.text)

                Picker("Vault", selection: $tab) {
                    Text("Private").tag(MemoryVisibility.private)
                    Text("Public").tag(MemoryVisibility.public)
                }
                .pickerStyle(.segmented)

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
                            VStack(spacing: 12) {
                                ForEach(filteredMemories) { memory in
                                    privateMemoryCard(memory)
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
                            VStack(spacing: 12) {
                                ForEach(publicFeed) { memory in
                                    publicMemoryCard(memory)
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

    private func privateMemoryCard(_ memory: MemoryItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(memory.caption)
                .font(ThemeFont.bodyStrong)
                .foregroundStyle(Theme.text)
            Text(memory.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(ThemeFont.caption)
                .foregroundStyle(Theme.text.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func publicMemoryCard(_ memory: CommunityMemory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.text.opacity(0.08))
                    .frame(height: 132)

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
                                .frame(height: 132)
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
                .font(ThemeFont.bodyStrong)
                .foregroundStyle(Theme.text)
                .lineLimit(2)

            HStack {
                Label(memory.placeName, systemImage: "mappin")
                    .font(ThemeFont.caption)
                    .foregroundStyle(Theme.sage)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "heart")
                    Text("\(memory.likes)")
                }
                .font(ThemeFont.caption)
                .foregroundStyle(Theme.text.opacity(0.6))
            }
        }
        .padding(10)
        .background(.white.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.text.opacity(0.08), lineWidth: 1)
        )
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

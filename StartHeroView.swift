import SwiftUI
import UIKit

struct StartHeroView: View {
    @EnvironmentObject var app: AppState
    @State private var showInfoSlides = false
    @State private var targetTab: AppState.AppTab = .home
    @State private var isStartingTransition = false

    private let leftColumnImages = ["bali", "milford", "amalfi", "aurora", "swiss-alps", "kyoto"]
    private let rightColumnImages = ["banff-lake", "sahara", "train", "chichen-itza", "maldives", "colosseum"]

    var body: some View {
        GeometryReader { geo in
            let topFadeHeight = max(90, geo.size.height * 0.12)
            let bottomFadeHeight = max(360, geo.size.height * 0.46)

            ZStack {
                Theme.bg.ignoresSafeArea()

                HeroParallaxColumns(
                    leftColumnImages: leftColumnImages,
                    rightColumnImages: rightColumnImages
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .ignoresSafeArea()
                .zIndex(0)

                VStack {
                    LinearGradient(
                        colors: [Theme.bg.opacity(0.92), Theme.bg.opacity(0.18), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: topFadeHeight)
                    Spacer()
                    LinearGradient(
                        colors: [.clear, Theme.bg.opacity(0.55), Theme.bg.opacity(0.97)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: bottomFadeHeight)
                }
                .ignoresSafeArea()
                .zIndex(1)

                // Airy/fog layer to soften the collage while keeping it visible.
                ZStack {
                    Rectangle()
                        .fill(Theme.bg.opacity(0.24))

                    LinearGradient(
                        colors: [
                            .white.opacity(0.20),
                            Theme.bg.opacity(0.10),
                            .clear,
                            Theme.bg.opacity(0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    RadialGradient(
                        colors: [.white.opacity(0.18), .clear],
                        center: .top,
                        startRadius: 30,
                        endRadius: 380
                    )

                    RadialGradient(
                        colors: [.white.opacity(0.10), .clear],
                        center: .bottomTrailing,
                        startRadius: 40,
                        endRadius: 360
                    )
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .zIndex(1.5)

                Rectangle()
                    .fill(Theme.bg.opacity(0.86))
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Theme.text.opacity(0.12))
                            .frame(height: 1)
                    }
                    .frame(height: max(250, geo.size.height * 0.31))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea(edges: .bottom)
                    .zIndex(2)
            }
            .overlay(alignment: .bottom) {
                heroBottomPanel
            }
            .overlay(alignment: .bottom) {
                Color.clear
                    .frame(height: geo.size.height * 0.25)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onEnded { value in
                                let shouldStart = value.translation.height < -40 || value.predictedEndTranslation.height < -70
                                if shouldStart { triggerStart() }
                            }
                    )
            }
        }
        .navigationDestination(isPresented: .init(
            get: { !app.isFirstLaunch },
            set: { _ in }
        )) {
            TabShellView()
                .navigationBarBackButtonHidden()
        }
        .navigationDestination(isPresented: $showInfoSlides) {
            OnboardingInfoSlidesView(finalTab: targetTab)
        }
    }

    private var heroBottomPanel: some View {
        VStack(spacing: 0) {
            Group {
                if let logo = UIImage(named: "sidequest-logo") ?? UIImage(named: "SideQuestHeroIcon") {
                    Image(uiImage: logo)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "map.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                        .foregroundStyle(Theme.terracotta)
                }
            }
            .frame(width: 112, height: 112)
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)

            Text("SideQuest")
                .font(.system(size: 54, weight: .bold, design: .serif))
                .foregroundStyle(Theme.text)
                .padding(.top, 10)

            Text("\"The most interesting way there.\"")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.terracotta)
                .italic()
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            slideUpStartControl

            Button {
                app.selectedTab = .explore
                app.completeOnboarding(signIn: false)
            } label: {
                Text("or browse nearby spots")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text.opacity(0.58))
                    .padding(.top, 8)
                    .padding(.bottom, 18)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var slideUpStartControl: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(Theme.text.opacity(0.26))
                .frame(width: 50, height: 5)
                .padding(.top, 18)

            HStack(spacing: 8) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                Text("Slide up to SideQuest")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Theme.text)
            .padding(.bottom, 2)
        }
    }

    private func triggerStart() {
        guard !isStartingTransition else { return }
        isStartingTransition = true
        targetTab = .home
        showInfoSlides = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isStartingTransition = false
        }
    }
}

private struct HeroParallaxColumns: View {
    let leftColumnImages: [String]
    let rightColumnImages: [String]

    var body: some View {
        GeometryReader { geo in
            let availableWidth = max(280, geo.size.width - 24)
            let columnSpacing: CGFloat = 12
            let tileSpacing: CGFloat = 12
            let tileWidth = (availableWidth - columnSpacing) / 2
            let tileHeight = tileWidth * 1.35

            let pairCount = min(leftColumnImages.count, rightColumnImages.count)
            let rows: [(String, String)] = (0..<pairCount).map { idx in
                (leftColumnImages[idx], rightColumnImages[idx])
            }

            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let loopHeight = totalHeight(itemCount: rows.count, tileHeight: tileHeight, spacing: tileSpacing)
                let offset = CGFloat((t * 13).truncatingRemainder(dividingBy: loopHeight))

                VStack(spacing: tileSpacing) {
                    ForEach(0..<(rows.count * 2), id: \.self) { idx in
                        let row = rows[idx % rows.count]
                        HStack(spacing: columnSpacing) {
                            HeroImageTile(name: row.0, width: tileWidth, height: tileHeight)
                            HeroImageTile(name: row.1, width: tileWidth, height: tileHeight)
                        }
                        .frame(width: availableWidth, height: tileHeight)
                    }
                }
                .frame(width: availableWidth, height: geo.size.height, alignment: .top)
                .offset(y: -offset)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
    }

    private func totalHeight(itemCount: Int, tileHeight: CGFloat, spacing: CGFloat) -> CGFloat {
        CGFloat(itemCount) * tileHeight + CGFloat(max(0, itemCount - 1)) * spacing
    }
}

private struct HeroImageTile: View {
    let name: String
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let resolvedName = resolveImageName(name)
        ZStack {
            if UIImage(named: resolvedName) != nil {
                Image(resolvedName)
                    .resizable()
                    .scaledToFill()
            } else {
                fallbackTile
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .clipped()
    }

    private var fallbackTile: some View {
        LinearGradient(
            colors: [Theme.gold.opacity(0.42), Theme.sage.opacity(0.32), Theme.terracotta.opacity(0.30)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.text.opacity(0.45))
                editorialTitle
            }
        }
    }

    private var editorialTitle: some View {
        let labels = ["Scenic", "Culture", "Nature", "Food", "Adventure", "Hidden", "Local"]
        let digits = Int(name.filter(\.isNumber)) ?? 0
        return Text(labels[digits % labels.count])
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.text.opacity(0.55))
    }

    private func resolveImageName(_ preferred: String) -> String {
        let digits = preferred.filter(\.isNumber)
        let plain = String(Int(digits) ?? 0)
        let zeroPadded = String(format: "%02d", Int(digits) ?? 0)

        let candidates = [
            preferred,
            "hero\(zeroPadded)", "hero\(plain)",
            "Hero\(zeroPadded)", "Hero\(plain)",
            "scenery\(zeroPadded)", "scenery\(plain)",
            "Scenery\(zeroPadded)", "Scenery\(plain)",
            "image\(zeroPadded)", "image\(plain)",
            "Image\(zeroPadded)", "Image\(plain)",
            "bali", "milford", "amalfi", "aurora", "swiss-alps", "kyoto",
            "banff-lake", "sahara", "train", "chichen-itza", "maldives", "colosseum"
        ]

        for candidate in candidates where UIImage(named: candidate) != nil {
            return candidate
        }
        return preferred
    }
}

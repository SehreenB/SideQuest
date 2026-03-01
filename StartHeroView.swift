import SwiftUI
import UIKit

struct StartHeroView: View {
    @EnvironmentObject var app: AppState
    @State private var showInfoSlides = false
    @State private var showModeSelection = false
    @State private var targetTab: AppState.AppTab = .home

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 90)

                Group {
                    if let icon = UIImage(named: "SideQuestHeroIcon") {
                        Image(uiImage: icon)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "map.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .padding(24)
                            .foregroundStyle(Theme.terracotta)
                    }
                }
                .frame(width: 152, height: 152)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.white.opacity(0.78))
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 10)

                Text("SideQuest")
                    .font(ThemeFont.heroTitle)
                    .foregroundStyle(Theme.text)
                    .padding(.top, 34)

                Text("\"The most interesting way there.\"")
                    .font(ThemeFont.quote)
                    .foregroundStyle(Theme.terracotta)
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                Text("Discovery-focused routes that turn every trip into an adventure worth remembering.")
                    .font(ThemeFont.body)
                    .foregroundStyle(Theme.text.opacity(0.48))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 24)

                Spacer().frame(height: 42)

                Button {
                    targetTab = .home
                    showInfoSlides = true
                } label: {
                    Text("Start a SideQuest")
                        .font(ThemeFont.button)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 19)
                        .background(Theme.terracotta)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)

                Button {
                    showModeSelection = true
                } label: {
                    Label("Explore nearby", systemImage: "mappin.and.ellipse")
                        .font(ThemeFont.bodyStrong)
                        .foregroundStyle(Theme.sage)
                        .padding(.top, 18)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    TabShellView()
                } label: {
                    EmptyView()
                }
                .hidden()

                Spacer(minLength: 18)
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
        .navigationDestination(isPresented: $showModeSelection) {
            ModeSelectionView()
        }
    }
}

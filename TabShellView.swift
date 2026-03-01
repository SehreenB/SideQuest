//
//  TabShellView.swift
//  SideQuest
//
//  Created by betul cetintas on 2026-02-28.
//


import SwiftUI

struct TabShellView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        TabView(selection: $app.selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppState.AppTab.home)

            NavigationStack { ModeSelectionView() }
                .tabItem { Label("Explore", systemImage: "safari") }
                .tag(AppState.AppTab.explore)

            NavigationStack { VaultView() }
                .tabItem { Label("Vault", systemImage: "archivebox") }
                .tag(AppState.AppTab.vault)

            NavigationStack { ChallengesView() }
                .tabItem { Label("Challenges", systemImage: "target") }
                .tag(AppState.AppTab.challenges)

            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(AppState.AppTab.profile)
        }
        .tint(Theme.terracotta)
    }
}

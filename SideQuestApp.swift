//
//  SideQuestApp.swift
//  SideQuest
//
//  Created by betul cetintas on 2026-02-28.
//

import SwiftUI
import GoogleMaps
import UIKit

@main
struct SideQuestApp: App {
    @StateObject private var appState = AppState()

    init() {
        GMSServices.provideAPIKey(APIKeys.googleMaps)
        configureTabBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 250/255, green: 247/255, blue: 242/255, alpha: 1)
        appearance.shadowColor = UIColor(red: 224/255, green: 216/255, blue: 208/255, alpha: 1)

        let normalColor = UIColor(red: 74/255, green: 53/255, blue: 45/255, alpha: 1)
        let selectedColor = UIColor(red: 194/255, green: 109/255, blue: 74/255, alpha: 1)

        let normalAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: normalColor,
            .font: UIFont.systemFont(ofSize: 12, weight: .medium)
        ]
        let selectedAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: selectedColor,
            .font: UIFont.systemFont(ofSize: 12, weight: .medium)
        ]

        [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance].forEach { item in
            item.normal.iconColor = normalColor
            item.selected.iconColor = selectedColor
            item.normal.titleTextAttributes = normalAttrs
            item.selected.titleTextAttributes = selectedAttrs
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().unselectedItemTintColor = normalColor
        UITabBar.appearance().tintColor = selectedColor

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.titleTextAttributes = [.foregroundColor: normalColor]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: normalColor]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = selectedColor
    }
}

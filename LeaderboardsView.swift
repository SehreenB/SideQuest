//
//  LeaderboardsView.swift
//  SideQuest
//
//  Created by betul cetintas on 2026-02-28.
//


import SwiftUI

struct LeaderboardsView: View {
    @State private var tab = 0

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack {
                Picker("Leaderboard", selection: $tab) {
                    Text("Weekly").tag(0)
                    Text("Neighborhood").tag(1)
                    Text("All-time").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(18)

                List {
                    ForEach(1..<11) { i in
                        HStack {
                            Text("#\(i)")
                                .fontWeight(W.w900)
                                .foregroundStyle(Theme.text)
                            Text("Explorer \(i)")
                                .foregroundStyle(Theme.text)
                            Spacer()
                            Text("\(1200 - i * 73) pts")
                                .foregroundStyle(Theme.text.opacity(0.72))
                        }
                        .listRowBackground(Theme.bg)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Leaderboards")
    }
}

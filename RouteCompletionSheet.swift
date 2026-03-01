//
//  RouteCompletionSheet.swift
//  SideQuest
//
//  Created by betul cetintas on 2026-02-28.
//


import SwiftUI

struct RouteCompletionSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) var dismiss
    let route: RoutePlan

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Route Complete")
                    .font(ThemeFont.sectionTitle)
                    .foregroundStyle(Theme.text)

                Text("+\(route.estimatedPoints) points earned")
                    .font(ThemeFont.bodyStrong)
                    .foregroundStyle(Theme.terracotta)

                Text("Day streak: \(app.user.streak) • Routes: \(app.user.routesCompleted)")
                    .font(ThemeFont.bodySmall)
                    .foregroundStyle(Theme.text.opacity(0.75))

                Button {
                    dismiss()
                } label: {
                    Text("Back to Home")
                        .font(ThemeFont.buttonSmall)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.terracotta)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.top, 8)
            }
            .padding(18)
        }
    }
}

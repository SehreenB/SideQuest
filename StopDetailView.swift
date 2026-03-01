//
//  StopDetailView.swift
//  SideQuest
//
//  Created by betul cetintas on 2026-02-28.
//


import SwiftUI

struct StopDetailView: View {
    @EnvironmentObject var app: AppState
    let stop: Spot
    let inRoute: Bool

    @State private var showMemorySheet = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Text(stop.name)
                    .font(ThemeFont.sectionTitle)
                    .foregroundStyle(Theme.text)

                Text(stop.shortDescription)
                    .font(ThemeFont.bodySmall)
                    .foregroundStyle(Theme.text.opacity(0.75))

                HStack(spacing: 10) {
                    Button {
                        app.registerCheckIn(at: stop)
                    } label: {
                        Text("Check In")
                            .font(ThemeFont.buttonSmall)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.sage)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Button {
                        showMemorySheet = true
                    } label: {
                        Text("Capture")
                            .font(ThemeFont.buttonSmall)
                            .frame(width: 110)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.6))
                            .foregroundStyle(Theme.terracotta)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }

                Spacer()
            }
            .padding(18)
        }
        .sheet(isPresented: $showMemorySheet) {
            MemoryCaptureSheet(spot: stop)
        }
        .navigationTitle("Stop")
    }
}

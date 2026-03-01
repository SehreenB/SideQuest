import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            Form {
                Section("Account") {
                    HStack {
                        Text("Name")
                            .foregroundStyle(Theme.text)
                        Spacer()
                        Text(app.user.displayName)
                            .foregroundStyle(Theme.text.opacity(0.72))
                    }
                    Toggle("Default public posting", isOn: $app.user.defaultPublicPosting)
                        .foregroundStyle(Theme.text)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                            .foregroundStyle(Theme.text)
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(Theme.text.opacity(0.72))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(Theme.text)
        }
        .navigationTitle("Settings")
    }
}

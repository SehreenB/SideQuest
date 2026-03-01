import SwiftUI

struct ReadyToExploreView: View {
    @EnvironmentObject var app: AppState

    let finalTab: AppState.AppTab

    @State private var isSigningIn = false
    @State private var errorText: String?

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 96)

                HStack {
                    Spacer()
                    progressDots
                    Spacer()
                }

                Spacer().frame(height: 44)

                iconCard

                Spacer().frame(height: 24)

                Text("Ready to explore?")
                    .font(ThemeFont.pageTitle)
                    .foregroundStyle(Theme.text)

                Text("Sign in to save your progress across devices, or continue as a guest.")
                    .font(ThemeFont.body)
                    .foregroundStyle(Theme.text.opacity(0.65))
                    .lineSpacing(2)
                    .padding(.top, 12)

                Spacer().frame(height: 34)

                Button {
                    Task { await continueWithGoogle() }
                } label: {
                    Text(isSigningIn ? "Connecting..." : "Continue with Google")
                        .font(ThemeFont.button)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.text)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
                .disabled(isSigningIn)

                Button {
                    continueAsGuest()
                } label: {
                    Text("Continue as Guest")
                        .font(ThemeFont.bodyStrong)
                        .foregroundStyle(Theme.text.opacity(0.65))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .padding(.top, 16)

                if let errorText {
                    Text(errorText)
                        .font(ThemeFont.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }

                Spacer()
            }
            .padding(.horizontal, 22)
        }
        .navigationBarBackButtonHidden(false)
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Theme.text.opacity(0.14))
                .frame(width: 8, height: 8)
            Circle()
                .fill(Theme.text.opacity(0.14))
                .frame(width: 8, height: 8)
            Capsule()
                .fill(Theme.terracotta)
                .frame(width: 46, height: 8)
            Circle()
                .fill(Theme.text.opacity(0.14))
                .frame(width: 8, height: 8)
        }
    }

    private var iconCard: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 36, weight: .bold))
            .foregroundStyle(Theme.terracotta)
            .frame(width: 76, height: 76)
            .background(.white.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @MainActor
    private func continueWithGoogle() async {
        isSigningIn = true
        errorText = nil
        defer { isSigningIn = false }

        do {
            let profile = try await Auth0Service.shared.signInWithGoogle()
            app.user.displayName = profile.name
            app.selectedTab = finalTab
            app.completeOnboarding(signIn: true)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func continueAsGuest() {
        app.selectedTab = finalTab
        app.completeOnboarding(signIn: false)
    }
}

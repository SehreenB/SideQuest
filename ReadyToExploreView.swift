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
                Spacer().frame(height: 84)

                HStack {
                    Spacer()
                    progressDots
                    Spacer()
                }

                Spacer().frame(height: 120)

                Rectangle()
                    .fill(Theme.terracotta)
                    .frame(width: 36, height: 2)
                    .clipShape(Capsule())

                Spacer().frame(height: 24)

                Text("Ready to explore?")
                    .font(.system(size: 58, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.text)

                Text("Sign in to save your progress across devices, or continue as a guest.")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text.opacity(0.65))
                    .lineSpacing(3)
                    .padding(.top, 12)

                Spacer().frame(height: 34)

                Button {
                    Task { await continueWithGoogle() }
                } label: {
                    Text(isSigningIn ? "Connecting..." : "Continue with Apple")
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
                    Task { await continueWithGoogle() }
                } label: {
                    Text("Continue with Google")
                        .font(ThemeFont.buttonSmall)
                        .foregroundStyle(Theme.text.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white.opacity(0.55))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Theme.text.opacity(0.12), lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
                .disabled(isSigningIn)
                .padding(.top, 14)

                if let errorText {
                    Text(errorText)
                        .font(ThemeFont.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }

                Spacer()

                Button {
                    continueAsGuest()
                } label: {
                    Text("Skip for now")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text.opacity(0.52))
                        .underline()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 24)
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

    @MainActor
    private func continueWithGoogle() async {
        isSigningIn = true
        errorText = nil
        defer { isSigningIn = false }

        do {
            let profile = try await Auth0Service.shared.signInWithGoogle()
            app.applySignedInProfile(name: profile.name, email: profile.email)
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

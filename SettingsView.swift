import SwiftUI
import AVFoundation

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @State private var isTestingVoice = false
    @State private var voiceStatusText: String?
    @State private var speechSynth = AVSpeechSynthesizer()

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

                Section("Voice") {
                    Button {
                        Task { await testElevenLabsVoice() }
                    } label: {
                        HStack {
                            Text(isTestingVoice ? "Testing..." : "Test ElevenLabs Voice")
                            Spacer()
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(Theme.terracotta)
                        }
                    }
                    .disabled(isTestingVoice)

                    Button("Stop Voice") {
                        ElevenLabsService.shared.stopPlayback()
                        speechSynth.stopSpeaking(at: .immediate)
                        voiceStatusText = "Playback stopped."
                    }
                    .foregroundStyle(Theme.text.opacity(0.75))

                    if let voiceStatusText {
                        Text(voiceStatusText)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.text.opacity(0.68))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(Theme.text)
        }
        .navigationTitle("Settings")
    }

    @MainActor
    private func testElevenLabsVoice() async {
        isTestingVoice = true
        defer { isTestingVoice = false }
        voiceStatusText = nil

        do {
            try await ElevenLabsService.shared.playGuide(text: "SideQuest voice check. Your audio guide is working.")
            voiceStatusText = "Voice test started successfully."
        } catch {
            let utterance = AVSpeechUtterance(string: "SideQuest local voice fallback is working.")
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.48
            speechSynth.speak(utterance)
            voiceStatusText = "\(error.localizedDescription) Using device fallback voice."
        }
    }
}

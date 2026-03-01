import Foundation
import AVFoundation

final class ElevenLabsService {
    static let shared = ElevenLabsService()

    private let apiKey = APIKeys.elevenLabs
    private let voiceID = APIKeys.elevenLabsVoiceID
    private var audioPlayer: AVAudioPlayer?
    private var cachedAudio: [String: Data] = [:]

    /// Generate TTS audio from text and return the audio data
    func generateMicroGuide(text: String) async throws -> Data {
        // Check cache first
        if let cached = cachedAudio[text] { return cached }

        let urlString = "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)"
        guard let url = URL(string: urlString) else {
            throw ElevenLabsError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_monolingual_v1",
            "voice_settings": [
                "stability": 0.6,
                "similarity_boost": 0.75,
                "style": 0.3,
                "use_speaker_boost": true
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            throw ElevenLabsError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        // Cache it
        cachedAudio[text] = data
        return data
    }

    /// Generate and immediately play audio
    func playGuide(text: String) async throws {
        let data = try await generateMicroGuide(text: text)
        try await MainActor.run {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.play()
        }
    }

    /// Generate a guide script with Gemini, then speak it with ElevenLabs
    func playSpotGuide(spotName: String, description: String) async throws {
        let gemini = GeminiService()
        let script = try await gemini.generateAudioScript(spotName: spotName, description: description)
        try await playGuide(text: script)
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    var isPlaying: Bool {
        audioPlayer?.isPlaying ?? false
    }
}

enum ElevenLabsError: LocalizedError {
    case invalidURL
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid ElevenLabs API URL"
        case .apiError(let code, let msg): return "ElevenLabs error \(code): \(msg)"
        }
    }
}

import Foundation
import UIKit
import CoreLocation

struct GeminiPhotoAnalysis: Codable {
    let tags: [String]
    let suggestedCaption: String
}

final class GeminiService {
    private let apiKey = APIKeys.gemini
    private let defaultModel = "gemini-2.0-flash"
    private let waypointModel = "gemini-2.5-flash"
    
    private func endpoint(for model: String) -> String {
        "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
    }

    struct PlaceLearningInsight: Codable {
        let index: Int
        let insight: String
    }

    struct NearbyPlaceCuration: Codable {
        let index: Int
        let reason: String
        let rank: Int
    }

    struct WaypointPayload: Codable {
        let waypoints: [Waypoint]
    }

    struct Waypoint: Codable {
        let name: String
        let address: String
        let lat: Double
        let lng: Double
        let description: String
    }

    // MARK: - Photo Analysis (Vision)

    func analyzePhoto(imageData: Data) async throws -> GeminiPhotoAnalysis {
        let base64 = imageData.base64EncodedString()

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": """
                    Analyze this photo taken during an urban exploration walk.
                    Return ONLY valid JSON with exactly these keys:
                    {
                      "tags": ["tag1", "tag2", "tag3", "tag4", "tag5"],
                      "suggestedCaption": "A warm, 12-word poetic caption for this moment."
                    }
                    Tags should describe the mood, setting, and visual elements (e.g. cozy, vintage, mural, green, waterfront).
                    """],
                    [
                        "inline_data": [
                            "mime_type": "image/jpeg",
                            "data": base64
                        ]
                    ]
                ]
            ]]
        ]

        let parsed = try await callGemini(body: body)
        return try decodeJSON(from: parsed)
    }

    /// Overload that accepts base64 string directly (for backward compat)
    func analyzePhoto(base64JPEG: String) async throws -> GeminiPhotoAnalysis {
        guard !base64JPEG.isEmpty, let data = Data(base64Encoded: base64JPEG) else {
            // If no real image, use text-only analysis
            return try await analyzePhotoTextOnly()
        }
        return try await analyzePhoto(imageData: data)
    }

    private func analyzePhotoTextOnly() async throws -> GeminiPhotoAnalysis {
        let body: [String: Any] = [
            "contents": [[
                "parts": [[
                    "text": """
                    Generate a photo analysis for an urban exploration walk photo.
                    Return ONLY valid JSON with exactly these keys:
                    {
                      "tags": ["tag1", "tag2", "tag3", "tag4", "tag5"],
                      "suggestedCaption": "A warm, 12-word poetic caption for this moment."
                    }
                    Tags should be evocative urban exploration tags like cozy, vintage, mural, hidden, golden hour, street art, etc.
                    """
                ]]
            ]]
        ]

        let parsed = try await callGemini(body: body)
        return try decodeJSON(from: parsed)
    }

    // MARK: - Route Reasoning

    func whyThisRoute(mode: String, stopNames: [String]) async throws -> String {
        let stops = stopNames.joined(separator: ", ")
        let body: [String: Any] = [
            "contents": [[
                "parts": [[
                    "text": """
                    You are a warm, local city guide. In exactly 2 sentences, explain why this \(mode) walking route through these stops is special: \(stops).
                    Be poetic but grounded. Mention what makes the detour worth it. Do not use quotes around your response.
                    """
                ]]
            ]]
        ]

        return try await callGemini(body: body)
    }

    // MARK: - Audio Guide Script

    func generateAudioScript(spotName: String, description: String) async throws -> String {
        let body: [String: Any] = [
            "contents": [[
                "parts": [[
                    "text": """
                    In 2-3 sentences, describe "\(spotName)" like a warm local guide talking to a curious walker.
                    Context: \(description)
                    Keep it conversational, calming, and story-driven. No more than 40 words.
                    """
                ]]
            ]]
        ]

        return try await callGemini(body: body)
    }

    // MARK: - Discovery Route Generation

    func discoverStops(city: String, mode: String, count: Int) async throws -> [DiscoveryEngine.DiscoveryStop] {
        let body: [String: Any] = [
            "contents": [[
                "parts": [[
                    "text": """
                    List \(count) hidden gems in \(city) for a \(mode) vibe.
                    Return ONLY a valid JSON array with these exact keys per object:
                    [{"name": "string", "lat": number, "lng": number, "desc": "string"}]
                    Make locations realistic with real coordinates. Keep descriptions under 15 words.
                    """
                ]]
            ]]
        ]

        let text = try await callGemini(body: body)
        // Strip markdown code fences if present
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else { return [] }
        return try JSONDecoder().decode([DiscoveryEngine.DiscoveryStop].self, from: data)
    }

    // MARK: - Place Learning Insights

    /// Returns short "why this is special" blurbs keyed by original array index.
    func learningInsights(for placeHints: [String], mode: String) async throws -> [Int: String] {
        guard !placeHints.isEmpty else { return [:] }

        let indexedHints = placeHints.enumerated()
            .map { "\($0.offset): \($0.element)" }
            .joined(separator: "\n")

        let body: [String: Any] = [
            "contents": [[
                "parts": [[
                    "text": """
                    You are a local culture guide.
                    For each place below, write one short sentence about why it is interesting, scenic, historic, or locally loved.
                    Keep each insight under 18 words, factual and engaging.
                    Return ONLY valid JSON array:
                    [{"index": 0, "insight": "string"}]
                    Include only valid indices from the list.

                    Mode: \(mode)
                    Places:
                    \(indexedHints)
                    """
                ]]
            ]]
        ]

        let text = try await callGemini(body: body)
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else { return [:] }
        let decoded = try JSONDecoder().decode([PlaceLearningInsight].self, from: data)

        var result: [Int: String] = [:]
        for item in decoded where item.index >= 0 && item.index < placeHints.count {
            let trimmed = item.insight.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                result[item.index] = trimmed
            }
        }
        return result
    }

    /// Curates nearby real places for the selected mode, with ranked order and short local-guide reasons.
    func curateNearbyPlaces(
        mode: String,
        userLocation: CLLocationCoordinate2D,
        placeHints: [String]
    ) async throws -> [NearbyPlaceCuration] {
        guard !placeHints.isEmpty else { return [] }

        let indexedHints = placeHints.enumerated()
            .map { "\($0.offset): \($0.element)" }
            .joined(separator: "\n")

        let body: [String: Any] = [
            "contents": [[
                "parts": [[
                    "text": """
                    You are a thoughtful local tour guide.
                    Given a navigation mode and the user's current coordinates, choose the best nearby places from the provided list.
                    Prioritize places that fit the mode and feel interesting to visit now.

                    Return ONLY valid JSON array with this exact schema:
                    [{"index": 0, "reason": "string", "rank": 1}]

                    Rules:
                    - Use only indices from the list below.
                    - Rank starts at 1 (best), no duplicates.
                    - Keep reason to one sentence under 16 words.
                    - Do not invent places or coordinates.

                    Mode: \(mode)
                    User location: \(userLocation.latitude), \(userLocation.longitude)
                    Candidate places:
                    \(indexedHints)
                    """
                ]]
            ]]
        ]

        let text = try await callGemini(body: body)
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else { return [] }
        let decoded = try JSONDecoder().decode([NearbyPlaceCuration].self, from: data)

        let valid = decoded
            .filter { $0.index >= 0 && $0.index < placeHints.count }
            .sorted { $0.rank < $1.rank }
        return valid
    }

    /// Generates ordered scenic waypoints for a user location/theme using strict JSON schema.
    func generateThemedWaypoints(
        lat: Double,
        lng: Double,
        travelMode: String,
        radiusKM: Double,
        theme: String,
        stops: Int
    ) async throws -> [Waypoint] {
        let clampedStops = max(1, min(10, stops))
        let normalizedMode: String = {
            let mode = travelMode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            switch mode {
            case "walking", "walk", "foot": return "walk"
            case "driving", "drive", "car", "auto": return "car"
            case "cycle", "cycling", "bike", "bicycle": return "cycle"
            default: return "walk"
            }
        }()

        let radiusByMode: [String: Double] = [
            "walk": 2,
            "car": 15,
            "cycle": 7
        ]
        let modeRadius = radiusByMode[normalizedMode] ?? 2
        let effectiveRadius = max(0.5, min(30, min(radiusKM, modeRadius)))

        let prompt = """
        You are a local tour guide AI for the SideQuest exploration app.
        A user is standing at latitude \(lat), longitude \(lng).
        Travel mode: "\(normalizedMode)" — only suggest places within \(effectiveRadius) km.
        Theme: "\(theme)"
        Number of stops requested: \(clampedStops)

        Return EXACTLY \(clampedStops) waypoints that fit the theme, are reachable within \(effectiveRadius) km,
        and make sense as a sequential route (ordered by logical walking/driving path).

        Respond ONLY with valid JSON — no markdown, no prose, no code fences.

        Schema:
        {
          "waypoints": [
            {
              "name": "Place Name",
              "address": "Full street address",
              "lat": 0.0,
              "lng": 0.0,
              "description": "One sentence about why this fits the theme and is worth visiting."
            }
          ]
        }
        """

        let body: [String: Any] = [
            "contents": [[
                "parts": [[
                    "text": prompt
                ]]
            ]],
            "tools": [[
                "google_search": [:]
            ]]
        ]

        let text: String
        do {
            text = try await callGemini(body: body, model: waypointModel)
        } catch {
            // Retry without grounding tool if the API shape differs for this key/project.
            let fallbackBody: [String: Any] = [
                "contents": [[
                    "parts": [[
                        "text": prompt
                    ]]
                ]]
            ]
            text = try await callGemini(body: fallbackBody, model: waypointModel)
        }

        let payload: WaypointPayload = try decodeLenientJSON(from: text)
        return Array(payload.waypoints.prefix(clampedStops))
    }

    // MARK: - Internal

    private func callGemini(body: [String: Any], model: String? = nil) async throws -> String {
        let selectedModel = model ?? defaultModel
        guard let url = URL(string: endpoint(for: selectedModel)) else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GeminiError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw GeminiError.parseError
        }

        return text
    }

    private func decodeJSON<T: Decodable>(from text: String) throws -> T {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw GeminiError.parseError
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func decodeLenientJSON<T: Decodable>(from text: String) throws -> T {
        if let decoded: T = try? decodeJSON(from: text) {
            return decoded
        }

        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let start = cleaned.firstIndex(of: "{"), let end = cleaned.lastIndex(of: "}") {
            let jsonSubstring = cleaned[start...end]
            if let data = String(jsonSubstring).data(using: .utf8) {
                return try JSONDecoder().decode(T.self, from: data)
            }
        }

        throw GeminiError.parseError
    }
}

enum GeminiError: LocalizedError {
    case invalidURL
    case apiError(statusCode: Int, message: String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Gemini API URL"
        case .apiError(let code, let msg): return "Gemini API error \(code): \(msg)"
        case .parseError: return "Failed to parse Gemini response"
        }
    }
}

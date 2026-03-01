import Foundation

struct RetellCallRequest: Codable {
    let fromNumber: String
    let toNumber: String
    let overrideAgentId: String
    let retellLlmDynamicVariables: [String: String]

    enum CodingKeys: String, CodingKey {
        case fromNumber = "from_number"
        case toNumber = "to_number"
        case overrideAgentId = "override_agent_id"
        case retellLlmDynamicVariables = "retell_llm_dynamic_variables"
    }
}

struct RetellCallResponse: Codable {
    let callId: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case callId = "call_id"
        case status
    }
}

enum RetellCallError: LocalizedError {
    case missingConfiguration
    case invalidURL
    case apiError(statusCode: Int, message: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Retell is not configured. Add a valid outbound from-number in APIKeys.retellFromNumber."
        case .invalidURL:
            return "Invalid Retell endpoint URL."
        case .apiError(let statusCode, let message):
            return "Retell error \(statusCode): \(message)"
        case .invalidResponse:
            return "Unexpected response from Retell."
        }
    }
}

final class RetellBookingService {
    static let shared = RetellBookingService()

    private let endpoint = "https://api.retellai.com/v2/create-phone-call"

    func initiateBookingCall(
        venueName: String,
        venuePhoneNumber: String,
        bookingType: String,
        userName: String,
        partySize: Int,
        preferredDate: String,
        preferredTime: String,
        specialRequests: String,
        numberOfTickets: Int?
    ) async throws -> RetellCallResponse {
        guard !APIKeys.retellFromNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RetellCallError.missingConfiguration
        }
        guard let url = URL(string: endpoint) else {
            throw RetellCallError.invalidURL
        }

        let payload = RetellCallRequest(
            fromNumber: APIKeys.retellFromNumber,
            toNumber: venuePhoneNumber,
            overrideAgentId: APIKeys.retellAgentID,
            retellLlmDynamicVariables: [
                "venue_name": venueName,
                "booking_type": bookingType,
                "user_name": userName,
                "party_size": "\(partySize)",
                "preferred_date": preferredDate,
                "preferred_time": preferredTime,
                "special_requests": specialRequests,
                "number_of_tickets": "\(numberOfTickets ?? 1)"
            ]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(APIKeys.retellAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RetellCallError.invalidResponse
        }
        guard http.statusCode == 200 || http.statusCode == 201 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw RetellCallError.apiError(statusCode: http.statusCode, message: body)
        }
        guard let decoded = try? JSONDecoder().decode(RetellCallResponse.self, from: data) else {
            throw RetellCallError.invalidResponse
        }
        return decoded
    }
}

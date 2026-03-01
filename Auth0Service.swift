import Foundation
import AuthenticationServices
import UIKit

struct Auth0Profile {
    let name: String
    let email: String?
    let pictureURL: URL?
}

enum Auth0ServiceError: LocalizedError {
    case missingConfig
    case cancelled
    case invalidCallback
    case missingIDToken
    case invalidTokenPayload

    var errorDescription: String? {
        switch self {
        case .missingConfig:
            return "Auth0 is not configured yet."
        case .cancelled:
            return "Sign in cancelled."
        case .invalidCallback:
            return "Invalid Auth0 callback."
        case .missingIDToken:
            return "Auth0 did not return an ID token."
        case .invalidTokenPayload:
            return "Unable to read Auth0 profile."
        }
    }
}

@MainActor
final class Auth0Service: NSObject {
    static let shared = Auth0Service()
    private var webAuthSession: ASWebAuthenticationSession?

    func signInWithGoogle() async throws -> Auth0Profile {
        guard APIKeys.auth0Domain != "YOUR_AUTH0_DOMAIN",
              APIKeys.auth0ClientID != "YOUR_AUTH0_CLIENT_ID" else {
            throw Auth0ServiceError.missingConfig
        }

        let callbackScheme = (Bundle.main.bundleIdentifier ?? "sidequest").lowercased()
        let redirectURI = "\(callbackScheme)://\(APIKeys.auth0Domain)/ios/\(callbackScheme)/callback"

        var components = URLComponents()
        components.scheme = "https"
        components.host = APIKeys.auth0Domain
        components.path = "/authorize"
        components.queryItems = [
            URLQueryItem(name: "client_id", value: APIKeys.auth0ClientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "id_token token"),
            URLQueryItem(name: "scope", value: "openid profile email"),
            URLQueryItem(name: "connection", value: "google-oauth2"),
            URLQueryItem(name: "prompt", value: "login"),
            URLQueryItem(name: "nonce", value: UUID().uuidString),
            URLQueryItem(name: "state", value: UUID().uuidString)
        ]

        guard let authURL = components.url else {
            throw Auth0ServiceError.invalidCallback
        }

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { url, error in
                if let error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: Auth0ServiceError.cancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                guard let url else {
                    continuation.resume(throwing: Auth0ServiceError.invalidCallback)
                    return
                }
                continuation.resume(returning: url)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            webAuthSession = session
            session.start()
        }

        guard let idToken = idTokenFromCallback(url: callbackURL) else {
            throw Auth0ServiceError.missingIDToken
        }

        return try decodeProfile(fromIDToken: idToken)
    }

    private func idTokenFromCallback(url: URL) -> String? {
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
           let idToken = queryItems.first(where: { $0.name == "id_token" })?.value,
           !idToken.isEmpty {
            return idToken
        }

        if let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment {
            let parts = fragment.split(separator: "&")
            for part in parts {
                let pair = part.split(separator: "=", maxSplits: 1)
                if pair.count == 2, pair[0] == "id_token" {
                    return String(pair[1])
                }
            }
        }

        return nil
    }

    private func decodeProfile(fromIDToken token: String) throws -> Auth0Profile {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else {
            throw Auth0ServiceError.invalidTokenPayload
        }

        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        while payload.count % 4 != 0 {
            payload.append("=")
        }

        guard let payloadData = Data(base64Encoded: payload),
              let json = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            throw Auth0ServiceError.invalidTokenPayload
        }

        let name = (json["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = json["email"] as? String
        let picture = (json["picture"] as? String).flatMap(URL.init(string:))

        guard let displayName = name, !displayName.isEmpty else {
            throw Auth0ServiceError.invalidTokenPayload
        }

        return Auth0Profile(name: displayName, email: email, pictureURL: picture)
    }
}

extension Auth0Service: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        return ASPresentationAnchor()
    }
}

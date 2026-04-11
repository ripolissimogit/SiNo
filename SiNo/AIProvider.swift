import Foundation
import Security

struct AIResponse {
    let positive: String
    let negative: String
}

protocol AIProvider {
    func generateResponses(for question: String) async throws -> AIResponse
}

// MARK: - Claude

struct ClaudeProvider: AIProvider {
    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String = "claude-haiku-4-5-20251001") {
        self.apiKey = apiKey
        self.model = model
    }

    func generateResponses(for question: String) async throws -> AIResponse {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 60,
            "messages": [
                ["role": "user", "content": """
                    Domanda: "\(question)"

                    Genera due imperativi opposti che rispondano alla domanda come inviti all'azione diretti.
                    Devono essere ordini secchi, tipo "COMPRALA" / "LASCIA", "PARTI" / "RESTA", "MANGIA" / "DIGIUNA".
                    Max 10 caratteri ciascuno. Tutto maiuscolo. Stessa lingua della domanda.
                    Sii creativo e contestuale, non generico.

                    Rispondi SOLO in questo formato esatto, nient'altro:
                    SI:imperativo positivo
                    NO:imperativo negativo
                    """]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.requestFailed
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw AIError.invalidResponse
        }

        return parse(text)
    }

    private func parse(_ text: String) -> AIResponse {
        var positive = "SÌ"
        var negative = "NO"

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("SI:") {
                positive = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("NO:") {
                negative = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
        }

        return AIResponse(positive: positive, negative: negative)
    }
}

enum AIError: Error {
    case requestFailed
    case invalidResponse
    case noAPIKey
}

// MARK: - Keychain helper

func loadAPIKey(service: String) -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess, let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
}

func saveAPIKey(service: String, value: String) {
    let data = value.data(using: .utf8)!
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecValueData as String: data
    ]
    SecItemDelete(query as CFDictionary)
    SecItemAdd(query as CFDictionary, nil)
}

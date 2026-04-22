import Foundation

enum AnthropicError: LocalizedError {
    case missingKey
    case httpStatus(Int, String)
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "ANTHROPIC_API_KEY not found in ~/.env.local"
        case .httpStatus(let code, let body):
            return "Anthropic API returned \(code): \(body)"
        case .malformedResponse:
            return "Could not parse Anthropic response"
        }
    }
}

enum Anthropic {
    /// POSTs to /v1/messages and returns the first text block of the first
    /// content item. Throws on network, HTTP, or parsing errors.
    static func translate(_ text: String) async throws -> String {
        guard let key = Config.apiKey() else { throw AnthropicError.missingKey }

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": Config.model,
            "max_tokens": Config.maxTokens,
            "messages": [
                ["role": "user", "content": Config.prompt + text],
            ],
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw AnthropicError.malformedResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AnthropicError.httpStatus(http.statusCode, body)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String else {
            throw AnthropicError.malformedResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

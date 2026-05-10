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
    /// URLSession with HTTP/3 disabled. macOS 26 attempts QUIC to
    /// api.anthropic.com and stalls until the 60s timeout, even though HTTP/2
    /// works fine. Forcing HTTP/2 makes the request return in ~1s.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    /// POSTs to /v1/messages and returns the first text block of the first
    /// content item. Throws on network, HTTP, or parsing errors.
    static func translate(_ text: String) async throws -> String {
        guard let key = Config.apiKey() else { throw AnthropicError.missingKey }

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.assumesHTTP3Capable = false
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

        var lastError: Error = AnthropicError.malformedResponse
        for attempt in 0..<3 {
            if attempt > 0 {
                try await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
                NSLog("[CopyTranslate] retry attempt %d", attempt)
            }
            do {
                let (data, response) = try await session.data(for: req)
                guard let http = response as? HTTPURLResponse else {
                    throw AnthropicError.malformedResponse
                }
                if (500..<600).contains(http.statusCode) {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    lastError = AnthropicError.httpStatus(http.statusCode, body)
                    continue
                }
                guard (200..<300).contains(http.statusCode) else {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    throw AnthropicError.httpStatus(http.statusCode, body)
                }
                return try parseResponse(data)
            } catch let error as URLError where error.code == .timedOut || error.code == .networkConnectionLost {
                lastError = error
                continue
            }
        }
        throw lastError
    }

    private static func parseResponse(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String else {
            throw AnthropicError.malformedResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

import Foundation
import CopyTranslateCore

enum AnthropicError: LocalizedError, Equatable {
    case missingKey
    case unauthorized          // 401 / 403
    case offline
    case httpStatus(Int)
    case malformed

    var errorDescription: String? {
        switch self {
        case .missingKey: return "No API key set — open Settings to add one."
        case .unauthorized: return "API key looks invalid — set it in Settings."
        case .offline: return "No internet connection."
        case .httpStatus(let code): return "Translation service error (\(code)). Try again."
        case .malformed: return "Couldn't read the translation."
        }
    }

    /// Whether the result window should surface a "Settings" shortcut.
    var isKeyProblem: Bool { self == .missingKey || self == .unauthorized }
}

enum Anthropic {
    /// URLSession with HTTP/3 disabled. macOS 26 attempts QUIC to
    /// api.anthropic.com and stalls until timeout; forcing HTTP/2 returns in ~1s.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    /// Streams a translation, invoking `onDelta` with each text chunk as it
    /// arrives. Throws a typed AnthropicError on failure.
    static func streamTranslate(_ text: String, target: String, onDelta: @escaping (String) -> Void) async throws {
        guard let key = Config.apiKey() else { throw AnthropicError.missingKey }

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.assumesHTTP3Capable = false // macOS 26 QUIC stall workaround — keep
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": Config.model,
            "max_tokens": Config.maxTokens,
            "stream": true,
            "messages": [["role": "user", "content": Config.prompt(target: target) + text]],
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (bytes, response) = try await session.bytes(for: req)
            guard let http = response as? HTTPURLResponse else { throw AnthropicError.malformed }
            guard (200..<300).contains(http.statusCode) else {
                if http.statusCode == 401 || http.statusCode == 403 { throw AnthropicError.unauthorized }
                // Drain a little of the error body into the log, never the user UI.
                var detail = ""
                for try await line in bytes.lines where detail.count < 500 { detail += line }
                NSLog("[CopyTranslate] HTTP %d: %@", http.statusCode, detail)
                throw AnthropicError.httpStatus(http.statusCode)
            }
            for try await line in bytes.lines {
                guard let json = SSEParser.dataPayload(from: line) else { continue }
                if let delta = SSEParser.textDelta(fromDataJSON: json) {
                    onDelta(delta)
                } else if SSEParser.isMessageStop(json) {
                    break
                }
            }
        } catch let error as AnthropicError {
            throw error
        } catch let error as URLError where [.notConnectedToInternet, .cannotConnectToHost, .networkConnectionLost, .timedOut].contains(error.code) {
            throw AnthropicError.offline
        }
    }
}

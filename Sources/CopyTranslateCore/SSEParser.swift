import Foundation

/// Parses Anthropic Messages API streaming (SSE) lines. The wire shape:
///   event: content_block_delta
///   data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hola"}}
/// We accumulate `delta.text` from every `text_delta` and stop at `message_stop`.
public enum SSEParser {
    /// Parse a single SSE line of the form `data: {...}` into a JSON object.
    /// Returns nil for `event:` lines, blanks, comments, and `[DONE]`.
    public static func dataPayload(from line: String) -> [String: Any]? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("data:") else { return nil }
        let payload = trimmed.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
        guard !payload.isEmpty, payload != "[DONE]",
              let data = payload.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj
    }

    /// Returns the text from a `content_block_delta`/`text_delta` payload, else nil.
    public static func textDelta(fromDataJSON json: [String: Any]) -> String? {
        guard (json["type"] as? String) == "content_block_delta",
              let delta = json["delta"] as? [String: Any],
              (delta["type"] as? String) == "text_delta",
              let text = delta["text"] as? String else { return nil }
        return text
    }

    public static func isMessageStop(_ json: [String: Any]) -> Bool {
        (json["type"] as? String) == "message_stop"
    }

    /// Convenience for tests / non-streaming batches: accumulate all text deltas
    /// from a sequence of raw SSE lines.
    public static func accumulatedText(from lines: [String]) -> String {
        var out = ""
        for line in lines {
            guard let json = dataPayload(from: line), let text = textDelta(fromDataJSON: json) else { continue }
            out += text
        }
        return out
    }
}

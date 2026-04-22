import Foundation

/// Runtime configuration. API key comes from `~/.env.local`, other prefs
/// are stored in UserDefaults.
enum Config {
    static let model = "claude-haiku-4-5"
    static let doubleTapWindow: TimeInterval = 0.4
    static let popupSize = CGSize(width: 820, height: 300)
    static let maxTokens = 1024
    static let prompt = """
        Translate the following text to English.
        If the text is already in English, translate it to Spanish instead.
        Output ONLY the translation — no preamble, no quotes, no notes, no labels.

        Text:

        """

    /// Reads ANTHROPIC_API_KEY from ~/.env.local. Supports `export KEY=...`
    /// and `KEY="..."` quoting styles. Returns nil when not found.
    static func apiKey() -> String? {
        if let env = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
           !env.isEmpty { return env }

        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".env.local")
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        for rawLine in contents.split(whereSeparator: \.isNewline) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("export ") { line = String(line.dropFirst("export ".count)) }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            if key != "ANTHROPIC_API_KEY" { continue }
            var value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            return value.isEmpty ? nil : value
        }
        return nil
    }
}

final class Preferences: ObservableObject {
    static let shared = Preferences()

    @Published var isPaused: Bool {
        didSet { UserDefaults.standard.set(isPaused, forKey: "isPaused") }
    }

    private init() {
        self.isPaused = UserDefaults.standard.bool(forKey: "isPaused")
    }
}

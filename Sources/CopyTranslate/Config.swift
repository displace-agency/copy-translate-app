import Foundation

/// Runtime configuration. API key comes from `~/.env.local`, other prefs
/// are stored in UserDefaults.
enum Config {
    static let model = "claude-haiku-4-5"
    static let doubleTapWindow: TimeInterval = 0.4
    static let popupSize = CGSize(width: 820, height: 300)
    static let maxTokens = 1024

    static let supportedLanguages = [
        "Spanish", "English", "French", "Portuguese", "German", "Italian",
        "Japanese", "Chinese (Simplified)", "Chinese (Traditional)", "Korean",
        "Arabic", "Russian", "Dutch", "Swedish", "Polish",
    ]

    static var targetLanguage: String {
        get { UserDefaults.standard.string(forKey: "targetLanguage") ?? "Spanish" }
        set { UserDefaults.standard.set(newValue, forKey: "targetLanguage") }
    }

    static var prompt: String {
        let lang = targetLanguage
        return """
            Translate the following text to \(lang).
            If the text is already in \(lang), translate it to English instead.
            Output ONLY the translation - no preamble, no quotes, no notes, no labels.

            Text:

            """
    }

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

    @Published var targetLanguage: String {
        didSet { Config.targetLanguage = targetLanguage }
    }

    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }

    @Published var doubleTapSpeed: Double {
        didSet { UserDefaults.standard.set(doubleTapSpeed, forKey: "doubleTapSpeed") }
    }

    private init() {
        self.isPaused = UserDefaults.standard.bool(forKey: "isPaused")
        self.targetLanguage = Config.targetLanguage
        self.soundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")
        self.doubleTapSpeed = UserDefaults.standard.double(forKey: "doubleTapSpeed").clamped(to: 0.2...0.8, default: 0.4)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>, default defaultValue: Double) -> Double {
        self == 0 ? defaultValue : Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

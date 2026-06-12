import Foundation
import CopyTranslateCore

/// Runtime configuration. The API key is resolved from the Keychain first, then
/// the `ANTHROPIC_API_KEY` environment variable, then `~/.env.local` (kept as a
/// fallback for power users). Other prefs live in UserDefaults.
enum Config {
    static let model = "claude-haiku-4-5"
    static let popupSize = CGSize(width: 820, height: 300)
    static let maxTokens = 1024

    static let supportedLanguages = Languages.all

    static var targetLanguage: String {
        get { UserDefaults.standard.string(forKey: "targetLanguage") ?? Languages.defaultLanguage }
        set { UserDefaults.standard.set(newValue, forKey: "targetLanguage") }
    }

    /// Translation instruction for the saved default language.
    static var prompt: String { PromptBuilder.translationPrompt(target: targetLanguage) }
    /// Translation instruction for an explicit per-request language.
    static func prompt(target: String) -> String { PromptBuilder.translationPrompt(target: target) }

    // MARK: - API key

    /// Resolved key, in precedence order. Reads Keychain first.
    static func apiKey() -> String? {
        if let k = Keychain.get() { return k }
        if let env = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !env.isEmpty { return env }
        if let fileKey = readEnvFileKey() { return fileKey }
        return nil
    }

    /// Where the active key came from (for the Settings UI).
    enum KeySource: String { case keychain, environment, envFile, none }
    static func keySource() -> KeySource {
        if Keychain.get() != nil { return .keychain }
        if let env = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !env.isEmpty { return .environment }
        if readEnvFileKey() != nil { return .envFile }
        return .none
    }

    /// On first launch, copy a key found only in env/.env.local into the Keychain
    /// so subsequent reads are local. Logs without ever printing the key value.
    static func migrateKeyToKeychainIfNeeded() {
        guard Keychain.get() == nil else { return }
        if let env = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !env.isEmpty {
            if Keychain.set(env) { NSLog("[CopyTranslate] imported API key from environment into Keychain") }
        } else if let fileKey = readEnvFileKey() {
            if Keychain.set(fileKey) { NSLog("[CopyTranslate] imported API key from ~/.env.local into Keychain") }
        }
    }

    private static func readEnvFileKey() -> String? {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".env.local")
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return EnvParsing.parseAPIKey(fromFileContents: contents)
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

    /// When on, clicking "copy translation" replaces the clipboard; otherwise the
    /// user's original copied text is left in place.
    @Published var replaceClipboard: Bool {
        didSet { UserDefaults.standard.set(replaceClipboard, forKey: "replaceClipboard") }
    }

    private init() {
        self.isPaused = UserDefaults.standard.bool(forKey: "isPaused")
        self.targetLanguage = Config.targetLanguage
        self.soundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")
        self.doubleTapSpeed = UserDefaults.standard.double(forKey: "doubleTapSpeed").clamped(to: 0.2...0.8, default: 0.4)
        self.replaceClipboard = UserDefaults.standard.bool(forKey: "replaceClipboard")
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>, default defaultValue: Double) -> Double {
        self == 0 ? defaultValue : Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

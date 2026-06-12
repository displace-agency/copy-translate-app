import Foundation

public enum PromptBuilder {
    /// The translation instruction prefix. The source text is appended by the caller.
    public static func translationPrompt(target: String) -> String {
        """
        Translate the following text to \(target).
        If the text is already in \(target), translate it to English instead.
        Output ONLY the translation - no preamble, no quotes, no notes, no labels.

        Text:

        """
    }
}

public enum CacheKey {
    /// Cache key for a (language, source) pair. Length-prefixing the language
    /// prevents collisions between languages whose names share a prefix.
    public static func make(language: String, source: String) -> String {
        "\(language.count):\(language)|\(source)"
    }
}

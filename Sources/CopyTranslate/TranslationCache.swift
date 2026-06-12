import Foundation
import CopyTranslateCore

final class TranslationCache {
    static let shared = TranslationCache()

    private var entries: [String: Entry] = [:]
    private let maxEntries = 200
    private let lock = NSLock()

    private struct Entry {
        let translation: String
        var lastAccess: Date
    }

    func lookup(source: String, targetLanguage: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        let key = cacheKey(source: source, targetLanguage: targetLanguage)
        guard var entry = entries[key] else { return nil }
        entry.lastAccess = Date()
        entries[key] = entry
        return entry.translation
    }

    func store(source: String, targetLanguage: String, translation: String) {
        lock.lock()
        defer { lock.unlock() }
        let key = cacheKey(source: source, targetLanguage: targetLanguage)
        entries[key] = Entry(translation: translation, lastAccess: Date())
        if entries.count > maxEntries {
            let oldest = entries.sorted { $0.value.lastAccess < $1.value.lastAccess }
            for (key, _) in oldest.prefix(entries.count - maxEntries) {
                entries.removeValue(forKey: key)
            }
        }
    }

    private func cacheKey(source: String, targetLanguage: String) -> String {
        CacheKey.make(language: targetLanguage, source: source)
    }
}

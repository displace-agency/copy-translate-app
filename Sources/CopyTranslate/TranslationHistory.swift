import Foundation

struct TranslationRecord: Codable, Identifiable {
    let id: UUID
    let source: String
    let translation: String
    let targetLanguage: String
    let timestamp: Date

    init(source: String, translation: String, targetLanguage: String) {
        self.id = UUID()
        self.source = source
        self.translation = translation
        self.targetLanguage = targetLanguage
        self.timestamp = Date()
    }
}

final class TranslationHistory: ObservableObject {
    static let shared = TranslationHistory()

    @Published private(set) var records: [TranslationRecord] = []
    private let maxRecords = 50
    private let fileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("agency.displace.CopyTranslate")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("history.json")
        self.records = Self.load(from: fileURL)
    }

    func add(source: String, translation: String, targetLanguage: String) {
        let record = TranslationRecord(source: source, translation: translation, targetLanguage: targetLanguage)
        records.insert(record, at: 0)
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }
        save()
    }

    func clear() {
        records = []
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func load(from url: URL) -> [TranslationRecord] {
        guard let data = try? Data(contentsOf: url),
              let records = try? JSONDecoder().decode([TranslationRecord].self, from: data) else {
            return []
        }
        return records
    }
}

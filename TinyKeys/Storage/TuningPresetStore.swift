import Foundation

struct TuningPresetStore {
    private let fileManager: FileManager
    private let fileURL: URL

    init(fileManager: FileManager = .default, bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "TinyKeys") {
        self.fileManager = fileManager
        let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        self.fileURL = applicationSupportURL
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
            .appendingPathComponent("SavedCustomTunings.json")
    }

    func load() -> [SavedCustomTuning] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([SavedCustomTuning].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ tunings: [SavedCustomTuning]) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(tunings)
        try data.write(to: fileURL, options: .atomic)
    }
}

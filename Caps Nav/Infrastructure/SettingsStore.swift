import Foundation
import OSLog

final class SettingsStore {
    private let environment: AppEnvironment
    private let fileManager: FileManager
    private let logger = AppLogger.make(category: "SettingsStore")

    init(environment: AppEnvironment, fileManager: FileManager = .default) {
        self.environment = environment
        self.fileManager = fileManager
    }

    func ensureSettingsFileExists(defaultSettings: AppSettings = .default) throws {
        guard !fileManager.fileExists(atPath: environment.settingsFileURL.path) else {
            return
        }

        try save(defaultSettings)
        logger.info("Created default settings.json at \(self.environment.settingsFileURL.path, privacy: .public)")
    }

    func load() throws -> AppSettings {
        let data = try Data(contentsOf: environment.settingsFileURL)
        let settings = try JSONDecoder.capsNav().decode(AppSettings.self, from: data)
        logger.info("Loaded settings from disk.")
        return settings
    }

    func save(_ settings: AppSettings) throws {
        let data = try JSONEncoder.capsNav().encode(settings)
        try data.write(to: environment.settingsFileURL, options: .atomic)
        logger.info("Saved settings. activeProfileId=\(settings.activeProfileId, privacy: .public)")
    }
}

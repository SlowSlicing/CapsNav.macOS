import Foundation
import OSLog

final class ProfileLoader {
    private let fileManager: FileManager
    private let logger = AppLogger.make(category: "ProfileLoader")

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func ensureDefaultProfileExists(at url: URL, defaultProfileData: Data) throws {
        guard !fileManager.fileExists(atPath: url.path) else {
            return
        }

        try defaultProfileData.write(to: url, options: .atomic)
        logger.info("Created default profile at \(url.path, privacy: .public)")
    }

    func loadProfile(at url: URL) throws -> Profile {
        let data = try Data(contentsOf: url)
        let profile = try JSONDecoder.capsNav().decode(Profile.self, from: data)
        try profile.validate()
        return profile
    }

    func saveProfile(_ profile: Profile, to url: URL) throws {
        try profile.validate()
        let data = try JSONEncoder.capsNav().encode(profile)
        try data.write(to: url, options: .atomic)
    }

    func deleteProfile(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try fileManager.removeItem(at: url)
    }

    func loadProfiles(from directoryURL: URL) throws -> [Profile] {
        let fileURLs = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension.lowercased() == "json" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        let profiles = try fileURLs.map(loadProfile(at:))
        logger.info("Loaded \(profiles.count, privacy: .public) profiles from disk.")
        return profiles
    }
}

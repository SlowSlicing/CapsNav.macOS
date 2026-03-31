import Foundation

struct AppEnvironment {
    let fileManager: FileManager
    let bundle: Bundle

    var applicationSupportDirectoryURL: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Caps Nav", isDirectory: true)
    }

    var legacyApplicationSupportDirectoryURL: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CapsNav", isDirectory: true)
    }

    var profilesDirectoryURL: URL {
        applicationSupportDirectoryURL.appendingPathComponent("profiles", isDirectory: true)
    }

    var settingsFileURL: URL {
        applicationSupportDirectoryURL.appendingPathComponent("settings.json", isDirectory: false)
    }

    var prefixRoutingStateFileURL: URL {
        applicationSupportDirectoryURL.appendingPathComponent("prefix-routing-state.json", isDirectory: false)
    }

    var statisticsFileURL: URL {
        applicationSupportDirectoryURL.appendingPathComponent("statistics.json", isDirectory: false)
    }

    var defaultProfileFileURL: URL {
        profilesDirectoryURL.appendingPathComponent("default.json", isDirectory: false)
    }

    func profileFileURL(for profileID: String) -> URL {
        profilesDirectoryURL.appendingPathComponent("\(profileID).json", isDirectory: false)
    }

    func prepareDirectories() throws {
        try migrateLegacyDirectoriesIfNeeded()
        try fileManager.createDirectory(at: applicationSupportDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: profilesDirectoryURL, withIntermediateDirectories: true)
    }

    func bundledDefaultProfileURL() -> URL? {
        bundle.url(forResource: "default-profile", withExtension: "json")
    }

    private func migrateLegacyDirectoriesIfNeeded() throws {
        guard fileManager.fileExists(atPath: legacyApplicationSupportDirectoryURL.path),
              !fileManager.fileExists(atPath: applicationSupportDirectoryURL.path) else {
            return
        }

        try fileManager.moveItem(
            at: legacyApplicationSupportDirectoryURL,
            to: applicationSupportDirectoryURL
        )
    }
}

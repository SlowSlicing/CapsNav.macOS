import Foundation

struct InitialSetupCoordinator {
    let environment: AppEnvironment
    let settingsStore: SettingsStore
    let profileLoader: ProfileLoader
    let defaultProfileProvider: DefaultProfileProvider

    func prepare() throws {
        try environment.prepareDirectories()
        try settingsStore.ensureSettingsFileExists()

        let defaultProfileData = try defaultProfileProvider.loadDefaultProfileData()
        try profileLoader.ensureDefaultProfileExists(
            at: environment.defaultProfileFileURL,
            defaultProfileData: defaultProfileData
        )
    }
}

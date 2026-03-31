import Foundation

struct ProfileSelection {
    let profiles: [Profile]
    let activeProfile: Profile
}

final class ProfileManager {
    func selectActiveProfile(from profiles: [Profile], preferredActiveProfileID: String) throws -> ProfileSelection {
        guard !profiles.isEmpty else {
            throw ProfileManagerError.emptyProfileList
        }

        if let preferredProfile = profiles.first(where: { $0.id == preferredActiveProfileID }) {
            return ProfileSelection(profiles: profiles, activeProfile: preferredProfile)
        }

        if let defaultProfile = profiles.first(where: { $0.id == AppSettings.default.activeProfileId }) {
            return ProfileSelection(profiles: profiles, activeProfile: defaultProfile)
        }

        return ProfileSelection(profiles: profiles, activeProfile: profiles[0])
    }

    func switchProfile(to profileID: String, from profiles: [Profile]) throws -> Profile {
        guard let profile = profiles.first(where: { $0.id == profileID }) else {
            throw ProfileManagerError.missingProfile(profileID)
        }

        return profile
    }
}

enum ProfileManagerError: LocalizedError {
    case emptyProfileList
    case missingProfile(String)

    var errorDescription: String? {
        switch self {
        case .emptyProfileList:
            return "当前没有可用的配置方案。"
        case let .missingProfile(profileID):
            return "找不到配置方案：\(profileID)。"
        }
    }
}

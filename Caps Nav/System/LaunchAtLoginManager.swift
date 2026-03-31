import Foundation
import OSLog
import ServiceManagement

enum LaunchAtLoginStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval

    var displayName: String {
        switch self {
        case .enabled:
            return "已启用"
        case .disabled:
            return "未启用"
        case .requiresApproval:
            return "等待系统批准"
        }
    }

    var isEnabledLike: Bool {
        switch self {
        case .enabled, .requiresApproval:
            return true
        case .disabled:
            return false
        }
    }
}

final class LaunchAtLoginManager {
    private let logger = AppLogger.make(category: "LaunchAtLogin")

    @discardableResult
    func refreshStatus() -> LaunchAtLoginStatus {
        let status: LaunchAtLoginStatus

        switch SMAppService.mainApp.status {
        case .enabled:
            status = .enabled
        case .requiresApproval:
            status = .requiresApproval
        case .notRegistered, .notFound:
            status = .disabled
        @unknown default:
            status = .disabled
        }

        logger.info("Launch at login status refreshed: \(status.displayName, privacy: .public)")
        return status
    }

    func update(isEnabled: Bool) throws -> LaunchAtLoginStatus {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            let refreshedStatus = refreshStatus()

            if refreshedStatus.isEnabledLike == isEnabled {
                return refreshedStatus
            }

            logger.error("Failed to update launch at login: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        return refreshStatus()
    }

    func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

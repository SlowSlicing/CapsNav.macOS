import Foundation

enum AppOperationalState: Equatable {
    case enabled
    case paused
    case permissionRequired

    static func resolve(
        isAppEnabled: Bool,
        accessibilityStatus: AccessibilityAuthorizationStatus
    ) -> AppOperationalState {
        guard isAppEnabled else {
            return .paused
        }

        return accessibilityStatus == .trusted ? .enabled : .permissionRequired
    }

    var displayName: String {
        switch self {
        case .enabled:
            return "已启用"
        case .paused:
            return "已暂停"
        case .permissionRequired:
            return "等待授权"
        }
    }

    var menuActionTitle: String {
        switch self {
        case .enabled, .permissionRequired:
            return "暂停 Caps Nav"
        case .paused:
            return "启用 Caps Nav"
        }
    }
}

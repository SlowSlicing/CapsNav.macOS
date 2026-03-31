import ApplicationServices
import Foundation
import OSLog

enum AccessibilityAuthorizationStatus: String {
    case unknown
    case trusted
    case notTrusted

    var displayName: String {
        switch self {
        case .unknown:
            return "未检查"
        case .trusted:
            return "已授权"
        case .notTrusted:
            return "未授权"
        }
    }
}

final class PermissionManager {
    private let logger = AppLogger.make(category: "PermissionManager")

    private(set) var accessibilityStatus: AccessibilityAuthorizationStatus = .unknown

    @discardableResult
    func refreshStatus() -> AccessibilityAuthorizationStatus {
        accessibilityStatus = AXIsProcessTrusted() ? .trusted : .notTrusted
        logger.info("Accessibility status refreshed: \(self.accessibilityStatus.rawValue, privacy: .public)")
        return accessibilityStatus
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        _ = refreshStatus()
    }
}

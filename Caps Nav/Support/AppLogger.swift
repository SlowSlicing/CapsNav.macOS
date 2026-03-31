import Foundation
import OSLog

enum AppLogger {
    static let subsystem = Bundle.main.bundleIdentifier ?? "CapsNav"

    static func make(category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}

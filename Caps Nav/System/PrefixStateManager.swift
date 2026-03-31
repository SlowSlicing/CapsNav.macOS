import CoreGraphics
import Foundation
import OSLog

final class PrefixStateManager {
    private let logger = AppLogger.make(category: "PrefixStateManager")

    var onStateChanged: ((Bool) -> Void)?

    private(set) var isPrefixActive = false
    private var currentPressStartedAt: Date?
    private var hadInteractionDuringCurrentPress = false

    func handlePrefixKeyDown() {
        guard currentPressStartedAt == nil else {
            logger.debug("Ignored repeated prefix keyDown while the current press is still active.")
            return
        }

        currentPressStartedAt = Date()
        hadInteractionDuringCurrentPress = false
        setPrefixActive(true, source: "remapped-prefix-key-down")
    }

    func handlePrefixKeyUp(tapThresholdMilliseconds: Int) -> Bool {
        let isShortTap = shouldTriggerDefaultCapsToggle(tapThresholdMilliseconds: tapThresholdMilliseconds)
        clearCurrentPressState()
        setPrefixActive(false, source: "remapped-prefix-key-up")
        return isShortTap
    }

    func handleRawCapsFlagsChangedFallback() {
        if isPrefixActive {
            clearCurrentPressState()
        } else {
            currentPressStartedAt = Date()
            hadInteractionDuringCurrentPress = false
        }
        setPrefixActive(!isPrefixActive, source: "raw-caps-fallback-toggle")
    }

    func noteInteractionDuringCurrentPress(source: String) {
        guard isPrefixActive, currentPressStartedAt != nil, !hadInteractionDuringCurrentPress else {
            return
        }

        hadInteractionDuringCurrentPress = true
        logger.debug("Recorded interaction during current prefix press: \(source, privacy: .public)")
    }

    func reset() {
        clearCurrentPressState()
        setPrefixActive(false, source: "reset")
    }

    private func shouldTriggerDefaultCapsToggle(tapThresholdMilliseconds: Int) -> Bool {
        guard tapThresholdMilliseconds > 0,
              let currentPressStartedAt,
              !hadInteractionDuringCurrentPress else {
            return false
        }

        let elapsedMilliseconds = Int(Date().timeIntervalSince(currentPressStartedAt) * 1_000)
        let isShortTap = elapsedMilliseconds <= tapThresholdMilliseconds

        logger.debug(
            "Evaluated prefix short tap. elapsedMs=\(elapsedMilliseconds, privacy: .public) thresholdMs=\(tapThresholdMilliseconds, privacy: .public) shortTap=\(isShortTap, privacy: .public)"
        )

        return isShortTap
    }

    private func clearCurrentPressState() {
        currentPressStartedAt = nil
        hadInteractionDuringCurrentPress = false
    }

    private func setPrefixActive(_ nextValue: Bool, source: String) {
        guard nextValue != isPrefixActive else {
            return
        }

        isPrefixActive = nextValue
        onStateChanged?(nextValue)
        logger.info("Prefix state changed to \(self.isPrefixActive, privacy: .public) via \(source, privacy: .public)")
    }
}

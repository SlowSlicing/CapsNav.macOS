import Foundation

@MainActor
final class ApplicationTerminationCoordinator {
    private let cleanup: () -> Void
    private let terminate: () -> Void

    private var hasCleanedUp = false

    init(
        cleanup: @escaping () -> Void,
        terminate: @escaping () -> Void
    ) {
        self.cleanup = cleanup
        self.terminate = terminate
    }

    func requestTermination() {
        performCleanupIfNeeded()
        terminate()
    }

    func applicationWillTerminate() {
        performCleanupIfNeeded()
    }

    private func performCleanupIfNeeded() {
        guard !hasCleanedUp else {
            return
        }

        hasCleanedUp = true
        cleanup()
    }
}

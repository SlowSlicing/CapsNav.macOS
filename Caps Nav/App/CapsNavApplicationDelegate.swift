import AppKit

@MainActor
final class CapsNavApplicationDelegate: NSObject, NSApplicationDelegate {
    weak var appBootstrap: AppBootstrap?

    func applicationWillTerminate(_ notification: Notification) {
        appBootstrap?.prepareForApplicationTermination()
    }
}

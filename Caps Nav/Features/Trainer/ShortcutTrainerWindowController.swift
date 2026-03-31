import AppKit
import SwiftUI

private let shortcutTrainerWindowPreferredContentSize = NSSize(width: 1320, height: 860)
private let shortcutTrainerWindowBaseMinimumContentSize = NSSize(width: 1080, height: 700)
private let shortcutTrainerWindowScreenInset: CGFloat = 24

@MainActor
final class ShortcutTrainerWindowController: NSObject, NSWindowDelegate {
    static let shared = ShortcutTrainerWindowController()

    private weak var appBootstrap: AppBootstrap?
    private var window: NSWindow?
    func show(appBootstrap: AppBootstrap) {
        self.appBootstrap = appBootstrap

        let window = ensureWindow(appBootstrap: appBootstrap)
        let screen = activeScreen(for: window)

        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        fitWindow(window, on: screen)

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        appBootstrap.handleShortcutTrainerWindowDidAppear()
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        appBootstrap?.handleShortcutTrainerWindowDidDisappear()
    }

    private func ensureWindow(appBootstrap: AppBootstrap) -> NSWindow {
        if let window {
            return window
        }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: shortcutTrainerWindowPreferredContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Caps Nav 快捷键练习"
        window.setContentSize(shortcutTrainerWindowPreferredContentSize)
        window.contentMinSize = shortcutTrainerWindowBaseMinimumContentSize
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior = [.moveToActiveSpace]
        window.tabbingMode = .disallowed
        window.isRestorable = false
        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: ShortcutTrainerView(
                appBootstrap: appBootstrap,
                onClose: { [weak self] in
                    self?.close()
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )

        self.window = window
        return window
    }

    private func activeScreen(for window: NSWindow) -> NSScreen? {
        NSScreen.screens.first(where: { screen in
            screen.frame.contains(NSEvent.mouseLocation)
        }) ?? window.screen ?? NSScreen.main
    }

    private func fitWindow(_ window: NSWindow, on screen: NSScreen?) {
        guard let visibleFrame = screen?.visibleFrame else {
            window.center()
            return
        }

        let boundedFrame = NSRect(
            x: visibleFrame.minX + shortcutTrainerWindowScreenInset,
            y: visibleFrame.minY + shortcutTrainerWindowScreenInset,
            width: max(visibleFrame.width - (shortcutTrainerWindowScreenInset * 2), 0),
            height: max(visibleFrame.height - (shortcutTrainerWindowScreenInset * 2), 0)
        )
        let maxContentSize = window.contentRect(forFrameRect: boundedFrame).size
        let fittedMinimumContentSize = NSSize(
            width: min(shortcutTrainerWindowBaseMinimumContentSize.width, maxContentSize.width),
            height: min(shortcutTrainerWindowBaseMinimumContentSize.height, maxContentSize.height)
        )
        let preferredContentSize = shortcutTrainerWindowPreferredContentSize
        let targetContentSize = NSSize(
            width: min(max(preferredContentSize.width, fittedMinimumContentSize.width), maxContentSize.width),
            height: min(max(preferredContentSize.height, fittedMinimumContentSize.height), maxContentSize.height)
        )

        window.contentMinSize = fittedMinimumContentSize

        var targetFrame = window.frameRect(forContentRect: NSRect(origin: .zero, size: targetContentSize))
        targetFrame.origin = NSPoint(
            x: visibleFrame.midX - (targetFrame.width / 2),
            y: visibleFrame.midY - (targetFrame.height / 2)
        )

        window.setFrame(targetFrame, display: true)
    }
}

enum ShortcutTrainerPresenter {
    @MainActor
    static func show(appBootstrap: AppBootstrap) {
        ShortcutTrainerWindowController.shared.show(appBootstrap: appBootstrap)
    }
}

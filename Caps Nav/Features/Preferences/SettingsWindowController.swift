import AppKit
import SwiftUI

private let settingsWindowDefaultSize = NSSize(width: 1280, height: 860)
private let settingsWindowMinimumSize = NSSize(width: 1160, height: 780)

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private weak var appBootstrap: AppBootstrap?
    private var window: NSWindow?
    private var hasPositionedWindow = false

    func show(appBootstrap: AppBootstrap) {
        self.appBootstrap = appBootstrap

        let window = ensureWindow(appBootstrap: appBootstrap)

        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        if !hasPositionedWindow || !isWindowFrameVisible(window.frame) {
            centerWindowOnActiveScreen(window)
            hasPositionedWindow = true
        }

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        appBootstrap.handleSettingsWindowDidAppear()
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        appBootstrap?.handleSettingsWindowDidDisappear()
    }

    private func ensureWindow(appBootstrap: AppBootstrap) -> NSWindow {
        if let window {
            return window
        }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: settingsWindowDefaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Caps Nav 设置"
        window.setContentSize(settingsWindowDefaultSize)
        window.minSize = settingsWindowMinimumSize
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior = [.moveToActiveSpace]
        window.tabbingMode = .disallowed
        window.isRestorable = false
        window.delegate = self
        updateContent(of: window, appBootstrap: appBootstrap)

        self.window = window
        return window
    }

    private func updateContent(of window: NSWindow, appBootstrap: AppBootstrap) {
        window.contentViewController = NSHostingController(
            rootView: PreferencesRootView(appBootstrap: appBootstrap)
                .frame(minWidth: settingsWindowMinimumSize.width, minHeight: settingsWindowMinimumSize.height)
        )
    }

    private func centerWindowOnActiveScreen(_ window: NSWindow) {
        let activeScreen = NSScreen.screens.first(where: { screen in
            screen.frame.contains(NSEvent.mouseLocation)
        }) ?? window.screen ?? NSScreen.main

        guard let visibleFrame = activeScreen?.visibleFrame else {
            window.center()
            return
        }

        let origin = NSPoint(
            x: visibleFrame.midX - (window.frame.width / 2),
            y: visibleFrame.midY - (window.frame.height / 2)
        )
        window.setFrameOrigin(origin)
    }

    private func isWindowFrameVisible(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(frame)
        }
    }
}

enum SettingsWindowPresenter {
    @MainActor
    static func show(appBootstrap: AppBootstrap) {
        SettingsWindowController.shared.show(appBootstrap: appBootstrap)
    }
}

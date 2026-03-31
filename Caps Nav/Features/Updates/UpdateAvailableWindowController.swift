import AppKit
import SwiftUI

let updateAvailableWindowSize = NSSize(width: 940, height: 640)

@MainActor
final class UpdateAvailableWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var onClose: (() -> Void)?

    func show(
        currentVersion: String,
        updateInfo: AppUpdateInfo,
        isSystemCompatible: Bool,
        onDownload: @escaping () -> Void,
        onOpenReleasePage: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.onClose = onClose

        let window = ensureWindow()
        window.contentViewController = NSHostingController(
            rootView: UpdateAvailableView(
                currentVersion: currentVersion,
                updateInfo: updateInfo,
                isSystemCompatible: isSystemCompatible,
                onDownload: onDownload,
                onOpenReleasePage: onOpenReleasePage,
                onClose: { [weak self] in
                    self?.close()
                }
            )
        )

        window.setContentSize(updateAvailableWindowSize)
        NSApplication.shared.activate(ignoringOtherApps: true)
        centerWindowOnActiveScreen(window)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    private func ensureWindow() -> NSWindow {
        if let window {
            return window
        }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: updateAvailableWindowSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Caps Nav 更新"
        window.titleVisibility = .hidden
        window.minSize = updateAvailableWindowSize
        window.maxSize = updateAvailableWindowSize
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior = [.moveToActiveSpace]
        window.delegate = self

        self.window = window
        return window
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
}

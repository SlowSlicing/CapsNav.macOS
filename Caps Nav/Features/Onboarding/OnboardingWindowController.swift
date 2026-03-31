import AppKit
import Combine
import SwiftUI

private let onboardingWindowSize = NSSize(width: 560, height: 640)

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate, ObservableObject {
    static let shared = OnboardingWindowController()

    private var window: NSWindow?
    private var onComplete: (() -> Void)?
    private var onSkip: (() -> Void)?
    private var onRequestPermission: (() -> Void)?
    private var onOpenTrainer: (() -> Void)?
    private var permissionStatus: AccessibilityAuthorizationStatus = .unknown
    private var isHandlingClose = false

    @Published var currentStep: OnboardingStep = .welcome

    func showIfNeeded(
        hasCompletedOnboarding: Bool,
        permissionStatus: AccessibilityAuthorizationStatus,
        onComplete: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        onRequestPermission: @escaping () -> Void,
        onOpenTrainer: @escaping () -> Void
    ) {
        guard !hasCompletedOnboarding else {
            return
        }

        show(
            permissionStatus: permissionStatus,
            onComplete: onComplete,
            onSkip: onSkip,
            onRequestPermission: onRequestPermission,
            onOpenTrainer: onOpenTrainer
        )
    }

    func show(
        permissionStatus: AccessibilityAuthorizationStatus,
        onComplete: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        onRequestPermission: @escaping () -> Void,
        onOpenTrainer: @escaping () -> Void
    ) {
        self.permissionStatus = permissionStatus
        self.onComplete = onComplete
        self.onSkip = onSkip
        self.onRequestPermission = onRequestPermission
        self.onOpenTrainer = onOpenTrainer
        currentStep = .welcome
        isHandlingClose = false

        let window = ensureWindow()

        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        centerWindowOnScreen(window)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        isHandlingClose = true
        window?.close()
        window = nil
        isHandlingClose = false
    }

    func updatePermissionStatus(_ status: AccessibilityAuthorizationStatus) {
        self.permissionStatus = status
        if let window {
            updateContent(of: window)
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard !isHandlingClose else {
            return
        }
        onSkip?()
    }

    private func ensureWindow() -> NSWindow {
        if let window {
            updateContent(of: window)
            return window
        }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: onboardingWindowSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "欢迎使用 Caps Nav"
        window.setContentSize(onboardingWindowSize)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior = [.moveToActiveSpace]
        window.tabbingMode = .disallowed
        window.isRestorable = false
        window.delegate = self
        updateContent(of: window)

        self.window = window
        return window
    }

    private func updateContent(of window: NSWindow) {
        window.contentViewController = NSHostingController(
            rootView: OnboardingRootView(
                controller: self,
                permissionStatus: permissionStatus,
                onComplete: { [weak self] in
                    self?.onComplete?()
                    self?.close()
                },
                onRequestPermission: { [weak self] in
                    self?.onRequestPermission?()
                },
                onOpenTrainer: { [weak self] in
                    self?.onOpenTrainer?()
                    self?.close()
                }
            )
            .frame(width: onboardingWindowSize.width, height: onboardingWindowSize.height)
        )
    }

    private func centerWindowOnScreen(_ window: NSWindow) {
        let activeScreen = NSScreen.screens.first(where: { screen in
            screen.frame.contains(NSEvent.mouseLocation)
        }) ?? window.screen ?? NSScreen.main

        guard let visibleFrame = activeScreen?.visibleFrame else {
            window.center()
            return
        }

        let frame = NSRect(
            origin: CGPoint(
                x: visibleFrame.midX - (onboardingWindowSize.width / 2),
                y: visibleFrame.midY - (onboardingWindowSize.height / 2)
            ),
            size: onboardingWindowSize
        )
        window.setFrame(frame, display: true)
    }
}

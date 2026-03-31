import AppKit
import Combine
import Foundation
import OSLog

private enum AppUpdateCheckTrigger: Equatable {
    case automatic
    case manual
}

@MainActor
final class AppBootstrap: ObservableObject {
    private static let globalToggleShortcutMissingModifierMessage = "全局开关快捷键至少要包含一个修饰键。"
    private static let globalToggleShortcutRegistrationFailedMessage = "全局开关快捷键注册失败，可能与系统或其他应用冲突。"

    @Published private(set) var startupState: StartupState = .idle
    @Published private(set) var settings: AppSettings = .default
    @Published private(set) var profiles: [Profile] = []
    @Published private(set) var activeProfileID: String = AppSettings.default.activeProfileId
    @Published private(set) var accessibilityStatus: AccessibilityAuthorizationStatus = .unknown
    @Published private(set) var launchAtLoginStatus: LaunchAtLoginStatus = .disabled
    @Published private(set) var prefixRoutingMode: PrefixRoutingMode = .inactive
    @Published private(set) var isPrefixActive = false
    @Published private(set) var highlightedPrefixTriggerSignature: String?
    @Published private(set) var lastResolvedActionDescription = "尚未触发任何映射"
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var globalToggleHotKeyRegistrationStatus: GlobalToggleHotKeyRegistrationStatus = .unconfigured
    @Published private(set) var usageStatistics: UsageStatistics = .default
    @Published private(set) var lastUpdateCheckDate: Date?
    @Published private(set) var lastUpdateCheckStatusDescription = "尚未检查更新"
    @Published private(set) var availableUpdateInfo: AppUpdateInfo?

    let environment: AppEnvironment

    private let settingsStore: SettingsStore
    private let statisticsStore: StatisticsStore
    private let profileLoader: ProfileLoader
    private let profileManager: ProfileManager
    private let appThemeController: AppThemeController
    private let permissionManager: PermissionManager
    private let settingsWindowController: SettingsWindowController
    private let accessibilityPermissionPromptController: AccessibilityPermissionPromptController
    private let shortcutTrainerWindowController: ShortcutTrainerWindowController
    private let launchAtLoginManager: LaunchAtLoginManager
    private let globalToggleHotKeyManager: GlobalToggleHotKeyManager
    private let prefixKeyRouter: PrefixKeyRouter
    private let prefixStateManager: PrefixStateManager
    private let capsLockToggleController: CapsLockToggleController
    private let actionResolver: ActionResolver
    private let eventEmitter: EventEmitter
    private let keyEventInterceptor: KeyEventInterceptor
    private let prefixIndicatorController: PrefixIndicatorController
    private let initialSetupCoordinator: InitialSetupCoordinator
    private let onboardingWindowController: OnboardingWindowController
    private let appUpdateService: AppUpdateService
    private let updateAvailableWindowController: UpdateAvailableWindowController
    private let logger = AppLogger.make(category: "AppBootstrap")
    private lazy var terminationCoordinator = ApplicationTerminationCoordinator(
        cleanup: { [weak self] in
            self?.shutdown()
        },
        terminate: {
            NSApplication.shared.terminate(nil)
        }
    )

    private var hasStarted = false
    private var isSettingsWindowPresented = false
    private var isAccessibilityPermissionPromptPresented = false
    private var isShortcutTrainerWindowPresented = false
    private var isUpdateWindowPresented = false
    private var activationObserver: NSObjectProtocol?
    private var lastPresentedUpdateVersion: String?

    init(fileManager: FileManager = .default, bundle: Bundle = .main) {
        let environment = AppEnvironment(fileManager: fileManager, bundle: bundle)
        let settingsStore = SettingsStore(environment: environment, fileManager: fileManager)
        let statisticsStore = StatisticsStore(environment: environment, fileManager: fileManager)
        let profileLoader = ProfileLoader(fileManager: fileManager)
        let profileManager = ProfileManager()
        let appThemeController = AppThemeController()
        let permissionManager = PermissionManager()
        let settingsWindowController = SettingsWindowController.shared
        let accessibilityPermissionPromptController = AccessibilityPermissionPromptController()
        let shortcutTrainerWindowController = ShortcutTrainerWindowController.shared
        let launchAtLoginManager = LaunchAtLoginManager()
        let globalToggleHotKeyManager = GlobalToggleHotKeyManager()
        let prefixKeyRouter = PrefixKeyRouter(
            stateStore: PrefixRoutingStateStore(
                fileURL: environment.prefixRoutingStateFileURL,
                fileManager: fileManager
            )
        )
        let prefixStateManager = PrefixStateManager()
        let capsLockToggleController = CapsLockToggleController()
        let actionResolver = ActionResolver()
        let eventEmitter = EventEmitter()
        let keyEventInterceptor = KeyEventInterceptor(
            permissionManager: permissionManager,
            prefixStateManager: prefixStateManager,
            actionResolver: actionResolver,
            eventEmitter: eventEmitter
        )
        let prefixIndicatorController = PrefixIndicatorController()
        let initialSetupCoordinator = InitialSetupCoordinator(
            environment: environment,
            settingsStore: settingsStore,
            profileLoader: profileLoader,
            defaultProfileProvider: DefaultProfileProvider(bundle: bundle)
        )
        let appUpdateService = AppUpdateService(feedURL: AppUpdateService.defaultFeedURL)

        self.environment = environment
        self.settingsStore = settingsStore
        self.statisticsStore = statisticsStore
        self.profileLoader = profileLoader
        self.profileManager = profileManager
        self.appThemeController = appThemeController
        self.permissionManager = permissionManager
        self.settingsWindowController = settingsWindowController
        self.accessibilityPermissionPromptController = accessibilityPermissionPromptController
        self.shortcutTrainerWindowController = shortcutTrainerWindowController
        self.launchAtLoginManager = launchAtLoginManager
        self.globalToggleHotKeyManager = globalToggleHotKeyManager
        self.prefixKeyRouter = prefixKeyRouter
        self.prefixStateManager = prefixStateManager
        self.capsLockToggleController = capsLockToggleController
        self.actionResolver = actionResolver
        self.eventEmitter = eventEmitter
        self.keyEventInterceptor = keyEventInterceptor
        self.prefixIndicatorController = prefixIndicatorController
        self.initialSetupCoordinator = initialSetupCoordinator
        self.onboardingWindowController = OnboardingWindowController.shared
        self.appUpdateService = appUpdateService
        self.updateAvailableWindowController = UpdateAvailableWindowController()

        self.keyEventInterceptor.activeProfileProvider = { [weak self] in
            self?.activeProfile
        }
        self.keyEventInterceptor.isEnabledProvider = { [weak self] in
            self?.operationalState == .enabled
        }
        self.keyEventInterceptor.prefixRoutingModeProvider = { [weak self] in
            self?.prefixRoutingMode ?? .inactive
        }
        self.keyEventInterceptor.capsTapThresholdMillisecondsProvider = { [weak self] in
            self?.settings.capsTapToggleThresholdMilliseconds ?? AppSettings.default.capsTapToggleThresholdMilliseconds
        }
        self.keyEventInterceptor.onResolvedAction = { [weak self] description in
            self?.lastResolvedActionDescription = description
        }
        self.keyEventInterceptor.onShortTapDetected = { [weak self] in
            Task { @MainActor [weak self] in
                self?.performDefaultCapsTapAction()
            }
        }
        self.keyEventInterceptor.onHighlightedTriggerChanged = { [weak self] triggerSignature in
            self?.handleHighlightedTriggerChanged(triggerSignature)
        }
        self.keyEventInterceptor.onError = { [weak self] message in
            self?.lastErrorMessage = message
        }
        self.keyEventInterceptor.onTriggerRecorded = { [weak self] signature in
            self?.handleTriggerRecorded(signature: signature)
        }
        self.prefixStateManager.onStateChanged = { [weak self] isActive in
            self?.handlePrefixStateChanged(isActive)
        }
        self.globalToggleHotKeyManager.onTriggered = { [weak self] in
            self?.toggleAppEnabled()
        }

        self.activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { [weak self] in
                guard let self else {
                    return
                }

                self.refreshAccessibilityStatus()
                self.updateOnboardingPermissionStatusIfNeeded()
            }
        }

    }

    var activeProfile: Profile? {
        profiles.first(where: { $0.id == activeProfileID })
    }

    var activeProfileName: String {
        activeProfile?.name ?? "暂无配置方案"
    }

    var capsTapToggleThresholdMilliseconds: Int {
        settings.capsTapToggleThresholdMilliseconds
    }

    var isAppEnabled: Bool {
        settings.isAppEnabled
    }

    var toggleAppShortcut: Shortcut? {
        settings.toggleAppShortcut
    }

    var operationalState: AppOperationalState {
        AppOperationalState.resolve(
            isAppEnabled: settings.isAppEnabled,
            accessibilityStatus: accessibilityStatus
        )
    }

    var isLaunchAtLoginEnabled: Bool {
        settings.launchAtLogin
    }

    var themePreference: AppThemePreference {
        settings.themePreference
    }

    var menuBarIconStyle: MenuBarIconStyle {
        settings.menuBarIconStyle
    }

    var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    var requiresLaunchAtLoginApproval: Bool {
        launchAtLoginStatus == .requiresApproval
    }

    var isPrefixIndicatorOverlayEnabled: Bool {
        settings.showPrefixIndicatorOverlay
    }

    var prefixIndicatorPlacement: PrefixIndicatorPlacement {
        settings.prefixIndicatorPlacement
    }

    var prefixIndicatorOpacityPercent: Int {
        settings.prefixIndicatorOpacityPercent
    }

    var hasCompletedOnboarding: Bool {
        settings.hasCompletedOnboarding
    }

    func start() {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        startupState = .starting
        lastErrorMessage = nil

        do {
            try initialSetupCoordinator.prepare()
            prefixKeyRouter.recoverPersistedRoutingIfNeeded()

            settings = try settingsStore.load()
            try migrateLegacySettingsIfNeeded()
            applyThemePreference(settings.themePreference)

            usageStatistics = try statisticsStore.load()

            let loadedProfiles = try profileLoader.loadProfiles(from: environment.profilesDirectoryURL)
            let migratedProfiles = try migrateProfilesIfNeeded(loadedProfiles)
            let orderedProfiles = orderedProfiles(migratedProfiles)
            let selection = try profileManager.selectActiveProfile(
                from: orderedProfiles,
                preferredActiveProfileID: settings.activeProfileId
            )

            profiles = selection.profiles
            activeProfileID = selection.activeProfile.id

            if activeProfileID != settings.activeProfileId || settings.profileOrderIds != profiles.map(\.id) {
                settings.activeProfileId = activeProfileID
                settings = settings.withProfileOrderIds(profiles.map(\.id))
                try settingsStore.save(settings)
            }

            try syncLaunchAtLoginStatusWithSettings()
            refreshGlobalToggleHotKeyRegistration()
            refreshAccessibilityStatus()
            startupState = .running
            NSApplication.shared.setActivationPolicy(.accessory)

            logger.info("App bootstrap completed. activeProfile=\(self.activeProfileID, privacy: .public)")

            showOnboardingIfNeeded()
            scheduleAutomaticUpdateCheckIfNeeded()
        } catch {
            startupState = .failed
            lastErrorMessage = error.localizedDescription
            logger.error("App bootstrap failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshAccessibilityStatus() {
        accessibilityStatus = permissionManager.refreshStatus()
        applyOperationalState()
    }

    func requestAccessibilityPermission() {
        openAccessibilityPermissionPrompt()
    }

    func requestSystemAccessibilityPermission() {
        permissionManager.requestAccessibilityPermission()
        refreshAccessibilityStatus()
    }

    func openAccessibilityPermissionPrompt() {
        prepareToOpenSettingsWindow()
        isAccessibilityPermissionPromptPresented = true
        accessibilityPermissionPromptController.show(
            appBootstrap: self,
            onClose: { [weak self] in
                self?.handleAccessibilityPermissionPromptDidClose()
            }
        )
    }

    func updateLaunchAtLoginEnabled(to isEnabled: Bool) {
        do {
            let updatedStatus = try launchAtLoginManager.update(isEnabled: isEnabled)
            let updatedSettings = settings.withLaunchAtLoginEnabled(updatedStatus.isEnabledLike)

            try settingsStore.save(updatedSettings)
            settings = updatedSettings
            launchAtLoginStatus = updatedStatus
            lastErrorMessage = nil

            logger.info("Updated launch at login state to \(updatedStatus.displayName, privacy: .public)")
        } catch {
            launchAtLoginStatus = launchAtLoginManager.refreshStatus()
            lastErrorMessage = "开机自启设置失败：\(error.localizedDescription)"
            logger.error("Failed to update launch at login: \(error.localizedDescription, privacy: .public)")
        }
    }

    func updateThemePreference(to themePreference: AppThemePreference) {
        let updatedSettings = settings.withThemePreference(themePreference)

        guard updatedSettings != settings else {
            applyThemePreference(themePreference)
            return
        }

        do {
            try settingsStore.save(updatedSettings)
            settings = updatedSettings
            applyThemePreference(themePreference)
            lastErrorMessage = nil

            logger.info("Updated app theme preference to \(themePreference.rawValue, privacy: .public).")
        } catch {
            lastErrorMessage = "主题设置保存失败：\(error.localizedDescription)"
            logger.error("Failed to update theme preference: \(error.localizedDescription, privacy: .public)")
        }
    }

    func updateMenuBarIconStyle(to menuBarIconStyle: MenuBarIconStyle) {
        let updatedSettings = settings.withMenuBarIconStyle(menuBarIconStyle)

        guard updatedSettings != settings else {
            return
        }

        do {
            try settingsStore.save(updatedSettings)
            settings = updatedSettings
            lastErrorMessage = nil

            logger.info("Updated menu bar icon style to \(menuBarIconStyle.rawValue, privacy: .public).")
        } catch {
            lastErrorMessage = "状态栏图标样式保存失败：\(error.localizedDescription)"
            logger.error("Failed to update menu bar icon style: \(error.localizedDescription, privacy: .public)")
        }
    }

    func openLaunchAtLoginSystemSettings() {
        launchAtLoginManager.openSystemSettingsLoginItems()
    }

    func updateAppEnabled(to isEnabled: Bool) {
        let updatedSettings = settings.withAppEnabled(isEnabled)

        guard updatedSettings != settings else {
            applyOperationalState()
            return
        }

        do {
            try settingsStore.save(updatedSettings)
            settings = updatedSettings
            applyOperationalState()
            switch operationalState {
            case .enabled:
                lastResolvedActionDescription = "Caps Nav 已恢复运行"
            case .paused:
                lastResolvedActionDescription = "Caps Nav 已暂停，Caps Lock 恢复系统原生行为"
            case .permissionRequired:
                lastResolvedActionDescription = "Caps Nav 已启用，等待辅助功能权限"
            }
            lastErrorMessage = nil

            logger.info("Updated app enabled state to \(isEnabled, privacy: .public).")
        } catch {
            lastErrorMessage = "运行总开关保存失败：\(error.localizedDescription)"
            logger.error("Failed to update app enabled state: \(error.localizedDescription, privacy: .public)")
        }
    }

    func toggleAppEnabled() {
        updateAppEnabled(to: !settings.isAppEnabled)
    }

    func updateToggleAppShortcut(to shortcut: Shortcut?) {
        let validationResult = GlobalToggleShortcutRules.validate(shortcut)

        guard validationResult == .valid else {
            lastErrorMessage = Self.globalToggleShortcutMissingModifierMessage
            return
        }

        let updatedSettings = settings.withToggleAppShortcut(shortcut)

        guard updatedSettings != settings else {
            refreshGlobalToggleHotKeyRegistration()
            return
        }

        do {
            try settingsStore.save(updatedSettings)
            settings = updatedSettings
            refreshGlobalToggleHotKeyRegistration()
            lastErrorMessage = nil

            logger.info("Updated global toggle shortcut to \(shortcut?.userFacingDescription ?? "none", privacy: .public).")
        } catch {
            lastErrorMessage = "全局开关快捷键保存失败：\(error.localizedDescription)"
            logger.error("Failed to update global toggle shortcut: \(error.localizedDescription, privacy: .public)")
        }
    }

    func switchActiveProfile(to profileID: String) {
        do {
            let selectedProfile = try profileManager.switchProfile(to: profileID, from: profiles)
            activeProfileID = selectedProfile.id
            settings.activeProfileId = selectedProfile.id
            try settingsStore.save(settings)
            lastErrorMessage = nil

            if settings.showPrefixIndicatorOverlay, isPrefixActive {
                prefixIndicatorController.update(
                    isActive: true,
                    routingMode: prefixRoutingMode,
                    profileName: activeProfileName,
                    helpEntries: prefixIndicatorHelpEntries,
                    placement: prefixIndicatorPlacement,
                    opacityPercent: prefixIndicatorOpacityPercent
                )
            }

            logger.info("Switched active profile to \(selectedProfile.id, privacy: .public)")
        } catch {
            lastErrorMessage = error.localizedDescription
            logger.error("Failed to switch profile: \(error.localizedDescription, privacy: .public)")
        }
    }

    func shutdown() {
        globalToggleHotKeyRegistrationStatus = globalToggleHotKeyManager.update(shortcut: nil)
        keyEventInterceptor.stop()
        prefixKeyRouter.deactivateRouting()
        prefixRoutingMode = .inactive
        isPrefixActive = false
        highlightedPrefixTriggerSignature = nil
        prefixIndicatorController.hideImmediately()
    }

    func quitApplication() {
        terminationCoordinator.requestTermination()
    }

    func prepareForApplicationTermination() {
        terminationCoordinator.applicationWillTerminate()
    }

    func prepareToOpenSettingsWindow() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func openSettingsWindow() {
        prepareToOpenSettingsWindow()
        settingsWindowController.show(appBootstrap: self)
    }

    func openShortcutTrainerWindow() {
        prepareToOpenSettingsWindow()
        shortcutTrainerWindowController.show(appBootstrap: self)
    }

    func showOnboardingIfNeeded() {
        onboardingWindowController.showIfNeeded(
            hasCompletedOnboarding: settings.hasCompletedOnboarding,
            permissionStatus: accessibilityStatus,
            onComplete: { [weak self] in
                self?.markOnboardingCompleted()
            },
            onSkip: { [weak self] in
                self?.markOnboardingCompleted()
            },
            onRequestPermission: { [weak self] in
                self?.requestSystemAccessibilityPermission()
                self?.onboardingWindowController.updatePermissionStatus(self?.accessibilityStatus ?? .unknown)
            },
            onOpenTrainer: { [weak self] in
                self?.markOnboardingCompleted()
                self?.openShortcutTrainerWindow()
            }
        )
    }

    func showOnboarding() {
        onboardingWindowController.show(
            permissionStatus: accessibilityStatus,
            onComplete: { [weak self] in
                self?.onboardingWindowController.close()
            },
            onSkip: { [weak self] in
                self?.onboardingWindowController.close()
            },
            onRequestPermission: { [weak self] in
                self?.requestSystemAccessibilityPermission()
                self?.onboardingWindowController.updatePermissionStatus(self?.accessibilityStatus ?? .unknown)
            },
            onOpenTrainer: { [weak self] in
                self?.onboardingWindowController.close()
                self?.openShortcutTrainerWindow()
            }
        )
    }

    private func updateOnboardingPermissionStatusIfNeeded() {
        onboardingWindowController.updatePermissionStatus(accessibilityStatus)
    }

    private func scheduleAutomaticUpdateCheckIfNeeded() {
        guard settings.hasCompletedOnboarding else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            Task { @MainActor [weak self] in
                await self?.performUpdateCheck(trigger: .automatic)
            }
        }
    }

    private func performUpdateCheck(trigger: AppUpdateCheckTrigger) async {
        let currentVersion = AppVersion(currentAppVersion)
        let result = await appUpdateService.fetchLatestUpdate(currentVersion: currentVersion)
        lastUpdateCheckDate = Date()

        switch result {
        case .noUpdate:
            availableUpdateInfo = nil
            lastUpdateCheckStatusDescription = "当前已是最新版本"

            if trigger == .manual {
                presentUpdateStatusAlert(
                    title: "Caps Nav 已是最新版本",
                    message: "当前版本 \(currentAppVersion) 已经是最新版本。"
                )
            }

        case let .updateAvailable(info):
            availableUpdateInfo = info

            let isSystemCompatible = info.minimumSupportedSystemVersion.map {
                ProcessInfo.processInfo.isOperatingSystemAtLeast($0)
            } ?? true

            lastUpdateCheckStatusDescription = isSystemCompatible
                ? "发现新版本 \(info.version)"
                : "发现新版本 \(info.version)，但当前系统版本不满足要求"

            if trigger == .automatic, lastPresentedUpdateVersion == info.version {
                return
            }

            presentAvailableUpdateWindow(
                updateInfo: info,
                isSystemCompatible: isSystemCompatible
            )

        case let .invalidPayload(message):
            lastUpdateCheckStatusDescription = "更新源格式无效"
            logger.error("Invalid update payload: \(message, privacy: .public)")

            if trigger == .manual {
                presentUpdateStatusAlert(
                    title: "检查更新失败",
                    message: "更新源格式无效，请稍后重试。"
                )
            }

        case let .failed(message):
            lastUpdateCheckStatusDescription = "检查更新失败"
            logger.error("Failed to fetch update feed: \(message, privacy: .public)")

            if trigger == .manual {
                presentUpdateStatusAlert(
                    title: "检查更新失败",
                    message: message
                )
            }
        }
    }

    private func presentAvailableUpdateWindow(
        updateInfo: AppUpdateInfo,
        isSystemCompatible: Bool
    ) {
        prepareToOpenSettingsWindow()
        isUpdateWindowPresented = true
        lastPresentedUpdateVersion = updateInfo.version

        updateAvailableWindowController.show(
            currentVersion: currentAppVersion,
            updateInfo: updateInfo,
            isSystemCompatible: isSystemCompatible,
            onDownload: { [weak self] in
                self?.openAvailableUpdateDownload()
            },
            onOpenReleasePage: { [weak self] in
                self?.openAvailableUpdateReleasePage()
            },
            onClose: { [weak self] in
                self?.handleUpdateWindowDidClose()
            }
        )
    }

    private func presentUpdateStatusAlert(title: String, message: String) {
        prepareToOpenSettingsWindow()

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "知道了")
        alert.runModal()

        restoreAccessoryActivationPolicyIfNeeded()
    }

    private func handleUpdateWindowDidClose() {
        isUpdateWindowPresented = false
        restoreAccessoryActivationPolicyIfNeeded()
    }

    private func handleTriggerRecorded(signature: String) {
        do {
            try statisticsStore.recordTrigger(signature: signature)
            usageStatistics = try statisticsStore.load()
        } catch {
            logger.error("Failed to record trigger: \(error.localizedDescription, privacy: .public)")
        }
    }

    func resetUsageStatistics() {
        do {
            try statisticsStore.reset()
            usageStatistics = .default
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "重置统计失败：\(error.localizedDescription)"
            logger.error("Failed to reset statistics: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func markOnboardingCompleted() {
        let updatedSettings = settings.withOnboardingCompleted(true)

        guard updatedSettings != settings else {
            return
        }

        do {
            try settingsStore.save(updatedSettings)
            settings = updatedSettings
            logger.info("Marked onboarding as completed.")
        } catch {
            logger.error("Failed to save onboarding completion state: \(error.localizedDescription, privacy: .public)")
        }
    }

    func handleSettingsWindowDidAppear() {
        guard !isSettingsWindowPresented else {
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        isSettingsWindowPresented = true
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func handleSettingsWindowDidDisappear() {
        guard isSettingsWindowPresented else {
            return
        }

        isSettingsWindowPresented = false
        restoreAccessoryActivationPolicyIfNeeded()
    }

    func handleShortcutTrainerWindowDidAppear() {
        guard !isShortcutTrainerWindowPresented else {
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        isShortcutTrainerWindowPresented = true
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func handleShortcutTrainerWindowDidDisappear() {
        guard isShortcutTrainerWindowPresented else {
            return
        }

        isShortcutTrainerWindowPresented = false
        restoreAccessoryActivationPolicyIfNeeded()
    }

    func updateCapsTapToggleThresholdMilliseconds(to value: Int) {
        let updatedSettings = settings.normalizedCapsTapToggleThreshold(value)

        guard updatedSettings != settings else {
            return
        }

        do {
            try settingsStore.save(updatedSettings)
            settings = updatedSettings
            lastErrorMessage = nil

            logger.info(
                "Updated Caps tap threshold to \(updatedSettings.capsTapToggleThresholdMilliseconds, privacy: .public) ms."
            )
        } catch {
            lastErrorMessage = error.localizedDescription
            logger.error("Failed to update Caps tap threshold: \(error.localizedDescription, privacy: .public)")
        }
    }

    func updatePrefixIndicatorOverlayEnabled(to isEnabled: Bool) {
        let updatedSettings = settings.withPrefixIndicatorOverlayEnabled(isEnabled)

        guard updatedSettings != settings else {
            return
        }

        do {
            try settingsStore.save(updatedSettings)
            settings = updatedSettings
            lastErrorMessage = nil

            if isEnabled, isPrefixActive {
                prefixIndicatorController.update(
                    isActive: true,
                    routingMode: prefixRoutingMode,
                    profileName: activeProfileName,
                    helpEntries: prefixIndicatorHelpEntries,
                    placement: prefixIndicatorPlacement,
                    opacityPercent: prefixIndicatorOpacityPercent
                )
            } else {
                prefixIndicatorController.hideImmediately()
            }

            logger.info("Updated prefix indicator overlay enabled state to \(isEnabled, privacy: .public).")
        } catch {
            lastErrorMessage = error.localizedDescription
            logger.error("Failed to update prefix indicator overlay setting: \(error.localizedDescription, privacy: .public)")
        }
    }

    func updatePrefixIndicatorPlacement(to placement: PrefixIndicatorPlacement) {
        let updatedSettings = settings.withPrefixIndicatorPlacement(placement)

        guard updatedSettings != settings else {
            return
        }

        do {
            try settingsStore.save(updatedSettings)
            settings = updatedSettings
            lastErrorMessage = nil
            refreshOverlayIfNeeded()

            logger.info("Updated prefix indicator placement to \(placement.rawValue, privacy: .public).")
        } catch {
            lastErrorMessage = error.localizedDescription
            logger.error("Failed to update prefix indicator placement: \(error.localizedDescription, privacy: .public)")
        }
    }

    func updatePrefixIndicatorOpacityPercent(to opacityPercent: Int) {
        let updatedSettings = settings.withPrefixIndicatorOpacityPercent(opacityPercent)

        guard updatedSettings != settings else {
            return
        }

        do {
            try settingsStore.save(updatedSettings)
            settings = updatedSettings
            lastErrorMessage = nil
            refreshOverlayIfNeeded()

            logger.info("Updated prefix indicator opacity to \(updatedSettings.prefixIndicatorOpacityPercent, privacy: .public) percent.")
        } catch {
            lastErrorMessage = error.localizedDescription
            logger.error("Failed to update prefix indicator opacity: \(error.localizedDescription, privacy: .public)")
        }
    }

    func updateActiveProfileMappingDescription(
        forTriggerSignature triggerSignature: String,
        to description: String?
    ) {
        let normalizedDescription = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextDescription = normalizedDescription?.isEmpty == true ? nil : normalizedDescription

        updateActiveProfile(reason: "Updated mapping description for trigger \(triggerSignature)") { profile in
            guard let mappingIndex = profile.mappings.firstIndex(where: {
                $0.trigger.signature == triggerSignature
            }) else {
                throw ActiveProfileMutationError.mappingNotFound
            }

            guard profile.mappings[mappingIndex].persistedDescription != nextDescription else {
                return false
            }

            profile.mappings[mappingIndex].description = nextDescription
            return true
        }
    }

    func updateActiveProfileMappingKey(
        forTriggerSignature triggerSignature: String,
        to newKey: String
    ) {
        let normalizedKey = newKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        updateActiveProfile(reason: "Updated mapping trigger for \(triggerSignature) to \(normalizedKey)") { profile in
            guard let mappingIndex = profile.mappings.firstIndex(where: {
                $0.trigger.signature == triggerSignature
            }) else {
                throw ActiveProfileMutationError.mappingNotFound
            }

            let currentMapping = profile.mappings[mappingIndex]
            let updatedTrigger = Trigger(key: normalizedKey, modifiers: currentMapping.trigger.modifiers)

            guard updatedTrigger != currentMapping.trigger else {
                return false
            }

            profile.mappings[mappingIndex] = Mapping(
                trigger: updatedTrigger,
                output: currentMapping.output,
                description: currentMapping.description
            )
            return true
        }
    }

    func updateActiveProfileMappingAction(
        forTriggerSignature triggerSignature: String,
        to action: BuiltinAction
    ) {
        updateActiveProfileMappingOutput(
            forTriggerSignature: triggerSignature,
            to: .builtin(action: action)
        )
    }

    func updateActiveProfileMappingOutput(
        forTriggerSignature triggerSignature: String,
        to output: Output
    ) {
        updateActiveProfile(reason: "Updated mapping output for \(triggerSignature) to \(output.debugDescription)") { profile in
            guard let mappingIndex = profile.mappings.firstIndex(where: {
                $0.trigger.signature == triggerSignature
            }) else {
                throw ActiveProfileMutationError.mappingNotFound
            }

            let currentMapping = profile.mappings[mappingIndex]
            let nextDescription = output.suggestedDescription

            guard currentMapping.output != output
                    || currentMapping.persistedDescription != nextDescription else {
                return false
            }

            profile.mappings[mappingIndex] = Mapping(
                trigger: currentMapping.trigger,
                output: output,
                description: nextDescription
            )
            return true
        }
    }

    func addActiveProfileMapping(
        key: String,
        action: BuiltinAction,
        description: String?
    ) {
        addActiveProfileMapping(
            key: key,
            output: .builtin(action: action),
            description: description ?? action.defaultShortcutDescription
        )
    }

    func addActiveProfileMapping(
        key: String,
        output: Output,
        description: String?
    ) {
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedDescription = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextDescription = normalizedDescription?.isEmpty == true
            ? nil
            : (normalizedDescription ?? output.suggestedDescription)

        updateActiveProfile(reason: "Added mapping for key \(normalizedKey)") { profile in
            profile.mappings.append(
                Mapping(
                    trigger: Trigger(key: normalizedKey, modifiers: []),
                    output: output,
                    description: nextDescription
                )
            )
            return true
        }
    }

    func deleteActiveProfileMapping(forTriggerSignature triggerSignature: String) {
        updateActiveProfile(reason: "Deleted mapping for trigger \(triggerSignature)") { profile in
            guard let mappingIndex = profile.mappings.firstIndex(where: {
                $0.trigger.signature == triggerSignature
            }) else {
                throw ActiveProfileMutationError.mappingNotFound
            }

            profile.mappings.remove(at: mappingIndex)
            return true
        }
    }

    @discardableResult
    func createProfileFromDefault(named profileName: String) -> Bool {
        createProfile(
            named: profileName,
            copying: Profile.default,
            insertingAfterProfileID: nil,
            sourceDescription: "default-profile"
        )
    }

    @discardableResult
    func duplicateProfile(profileID: String, named profileName: String) -> Bool {
        guard let sourceProfile = profiles.first(where: { $0.id == profileID }) else {
            lastErrorMessage = "找不到需要复制的配置方案。"
            return false
        }

        return createProfile(
            named: profileName,
            copying: sourceProfile,
            insertingAfterProfileID: profileID,
            sourceDescription: "profile-copy-\(profileID)"
        )
    }

    private func createProfile(
        named profileName: String,
        copying sourceProfile: Profile,
        insertingAfterProfileID: String?,
        sourceDescription: String
    ) -> Bool {
        let normalizedProfileName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedProfileName.isEmpty else {
            lastErrorMessage = "请输入配置方案名称。"
            return false
        }

        let hasDuplicatedName = profiles.contains { existingProfile in
            existingProfile.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(normalizedProfileName) == .orderedSame
        }

        guard !hasDuplicatedName else {
            lastErrorMessage = "已存在同名配置方案，请换一个名称。"
            return false
        }

        let newProfile = Profile(
            id: "profile-\(UUID().uuidString.lowercased())",
            name: normalizedProfileName,
            version: sourceProfile.version,
            mappings: sourceProfile.mappings
        )

        do {
            try profileLoader.saveProfile(
                newProfile,
                to: environment.profileFileURL(for: newProfile.id)
            )

            var updatedProfiles = profiles
            let insertIndex: Int

            if let insertingAfterProfileID,
               let sourceIndex = updatedProfiles.firstIndex(where: { $0.id == insertingAfterProfileID }) {
                insertIndex = sourceIndex + 1
            } else {
                insertIndex = 0
            }

            updatedProfiles.insert(newProfile, at: min(insertIndex, updatedProfiles.count))
            profiles = updatedProfiles
            activeProfileID = newProfile.id
            settings.activeProfileId = newProfile.id
            settings = settings.withProfileOrderIds(updatedProfiles.map(\.id))
            try settingsStore.save(settings)
            lastErrorMessage = nil

            logger.info("Created a new profile from \(sourceDescription, privacy: .public): \(newProfile.id, privacy: .public)")
            return true
        } catch {
            lastErrorMessage = "新增配置方案失败：\(error.localizedDescription)"
            logger.error("Failed to create profile from \(sourceDescription, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func openPathInFinder(_ url: URL, revealInParent: Bool = false) {
        if revealInParent {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    func checkForUpdates() {
        Task { @MainActor [weak self] in
            await self?.performUpdateCheck(trigger: .manual)
        }
    }

    func openAvailableUpdateDownload() {
        guard let availableUpdateInfo else {
            return
        }

        NSWorkspace.shared.open(availableUpdateInfo.downloadURL)
    }

    func openAvailableUpdateReleasePage() {
        guard let availableUpdateInfo else {
            return
        }

        NSWorkspace.shared.open(availableUpdateInfo.pageURL)
    }

    @discardableResult
    func renameProfile(profileID: String, to newName: String) -> Bool {
        let normalizedProfileName = newName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard profileID != Profile.default.id else {
            lastErrorMessage = "默认方案不能修改名称，请复制后再自定义。"
            return false
        }

        guard !normalizedProfileName.isEmpty else {
            lastErrorMessage = "请输入配置方案名称。"
            return false
        }

        guard let profileIndex = profiles.firstIndex(where: { $0.id == profileID }) else {
            lastErrorMessage = "找不到需要重命名的配置方案。"
            return false
        }

        let currentProfile = profiles[profileIndex]

        guard currentProfile.name != normalizedProfileName else {
            lastErrorMessage = nil
            return true
        }

        guard !isDuplicateProfileName(normalizedProfileName, excludingProfileID: profileID) else {
            lastErrorMessage = "已存在同名配置方案，请换一个名称。"
            return false
        }

        do {
            var renamedProfile = currentProfile
            renamedProfile.name = normalizedProfileName

            try profileLoader.saveProfile(
                renamedProfile,
                to: environment.profileFileURL(for: renamedProfile.id)
            )

            profiles[profileIndex] = renamedProfile
            lastErrorMessage = nil
            refreshOverlayIfNeeded()

            logger.info("Renamed profile \(profileID, privacy: .public) to \(normalizedProfileName, privacy: .public)")
            return true
        } catch {
            lastErrorMessage = "修改配置方案名称失败：\(error.localizedDescription)"
            logger.error("Failed to rename profile: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func deleteProfile(profileID: String) {
        guard profileID != Profile.default.id else {
            lastErrorMessage = "默认方案不能删除，请至少保留它作为基础方案。"
            return
        }

        guard profiles.count > 1 else {
            lastErrorMessage = "至少保留一个配置方案，无法删除当前唯一方案。"
            return
        }

        guard let profileIndex = profiles.firstIndex(where: { $0.id == profileID }) else {
            lastErrorMessage = "找不到需要删除的配置方案。"
            return
        }

        let profileToDelete = profiles[profileIndex]

        do {
            try profileLoader.deleteProfile(at: environment.profileFileURL(for: profileToDelete.id))

            var remainingProfiles = profiles
            remainingProfiles.remove(at: profileIndex)

            profiles = remainingProfiles
            settings = settings.withProfileOrderIds(remainingProfiles.map(\.id))

            if activeProfileID == profileID, let fallbackProfile = remainingProfiles.first {
                activeProfileID = fallbackProfile.id
                settings.activeProfileId = fallbackProfile.id
            }

            try settingsStore.save(settings)

            lastErrorMessage = nil
            refreshOverlayIfNeeded()

            logger.info("Deleted profile \(profileID, privacy: .public)")
        } catch {
            lastErrorMessage = "删除配置方案失败：\(error.localizedDescription)"
            logger.error("Failed to delete profile: \(error.localizedDescription, privacy: .public)")
        }
    }

    func reorderProfiles(draggedProfileID: String, to targetProfileID: String) {
        guard draggedProfileID != targetProfileID,
              let fromIndex = profiles.firstIndex(where: { $0.id == draggedProfileID }),
              let toIndex = profiles.firstIndex(where: { $0.id == targetProfileID }) else {
            return
        }

        var reorderedProfiles = profiles
        let movedProfile = reorderedProfiles.remove(at: fromIndex)
        reorderedProfiles.insert(movedProfile, at: toIndex)

        do {
            settings = settings.withProfileOrderIds(reorderedProfiles.map(\.id))
            try settingsStore.save(settings)
            profiles = reorderedProfiles
            lastErrorMessage = nil

            logger.info(
                "Reordered profiles. moved=\(draggedProfileID, privacy: .public) target=\(targetProfileID, privacy: .public)"
            )
        } catch {
            lastErrorMessage = "更新配置方案顺序失败：\(error.localizedDescription)"
            logger.error("Failed to reorder profiles: \(error.localizedDescription, privacy: .public)")
        }
    }

    deinit {
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
    }

    private func handlePrefixStateChanged(_ isActive: Bool) {
        isPrefixActive = isActive

        if !isActive {
            highlightedPrefixTriggerSignature = nil
        }

        guard settings.showPrefixIndicatorOverlay else {
            prefixIndicatorController.hideImmediately()
            return
        }

        prefixIndicatorController.update(
            isActive: isActive,
            routingMode: prefixRoutingMode,
            profileName: activeProfileName,
            helpEntries: isActive ? prefixIndicatorHelpEntries : [],
            placement: prefixIndicatorPlacement,
            opacityPercent: prefixIndicatorOpacityPercent
        )
    }

    private func applyOperationalState() {
        switch operationalState {
        case .enabled:
            accessibilityPermissionPromptController.close()
            isAccessibilityPermissionPromptPresented = false
            prefixRoutingMode = prefixKeyRouter.activatePreferredRouting()
            keyEventInterceptor.start()

        case .paused:
            stopPrefixFeatures()

        case .permissionRequired:
            stopPrefixFeatures()
        }
    }

    private func stopPrefixFeatures() {
        keyEventInterceptor.stop()
        prefixKeyRouter.deactivateRouting()
        prefixRoutingMode = .inactive
        isPrefixActive = false
        highlightedPrefixTriggerSignature = nil
        prefixIndicatorController.hideImmediately()
    }

    private func refreshGlobalToggleHotKeyRegistration() {
        let status = globalToggleHotKeyManager.update(shortcut: settings.toggleAppShortcut)
        globalToggleHotKeyRegistrationStatus = status

        if case .registrationFailed = status {
            lastErrorMessage = Self.globalToggleShortcutRegistrationFailedMessage
        } else if case .invalidShortcut = status {
            lastErrorMessage = Self.globalToggleShortcutMissingModifierMessage
        } else if lastErrorMessage == Self.globalToggleShortcutRegistrationFailedMessage
                    || lastErrorMessage == Self.globalToggleShortcutMissingModifierMessage {
            lastErrorMessage = nil
        }
    }

    private func performDefaultCapsTapAction() {
        guard accessibilityStatus == .trusted else {
            return
        }

        if prefixRoutingMode == .remappedF18 {
            prefixKeyRouter.deactivateRouting()
        }

        guard capsLockToggleController.toggleCapsLock() else {
            lastErrorMessage = "Caps 短按回退失败，请先确认辅助功能权限，然后再重试。"

            if prefixRoutingMode == .remappedF18 {
                prefixRoutingMode = prefixKeyRouter.activatePreferredRouting()
            }

            return
        }

        if prefixRoutingMode == .remappedF18 {
            prefixRoutingMode = prefixKeyRouter.activatePreferredRouting()
        }

        lastResolvedActionDescription = "Caps 短按 -> 系统默认大小写切换"
        lastErrorMessage = nil
    }

    private var prefixIndicatorHelpEntries: [PrefixIndicatorHelpEntry] {
        guard let activeProfile else {
            return []
        }

        return activeProfile.mappings.map { mapping in
            PrefixIndicatorHelpEntry(
                id: mapping.trigger.signature,
                triggerText: mapping.trigger.prefixIndicatorDisplayText,
                actionText: mapping.displayDescription,
                isHighlighted: mapping.trigger.signature == highlightedPrefixTriggerSignature
            )
        }
    }

    private func migrateProfilesIfNeeded(_ loadedProfiles: [Profile]) throws -> [Profile] {
        var migratedProfiles = loadedProfiles

        guard let defaultProfileIndex = migratedProfiles.firstIndex(where: { $0.id == Profile.default.id }) else {
            return migratedProfiles
        }

        let currentDefaultProfile = migratedProfiles[defaultProfileIndex]
        let migratedDefaultProfile: Profile

        if currentDefaultProfile.matchesLegacyDefaultV1 {
            migratedDefaultProfile = Profile.default
            logger.info("Migrated legacy default profile to the new bundled shortcuts.")
        } else {
            let backfilledProfile = currentDefaultProfile.backfilledDescriptions(using: Profile.default)

            guard backfilledProfile != currentDefaultProfile else {
                return migratedProfiles
            }

            migratedDefaultProfile = backfilledProfile
            logger.info("Backfilled missing descriptions for the default profile.")
        }

        try profileLoader.saveProfile(
            migratedDefaultProfile,
            to: environment.profileFileURL(for: migratedDefaultProfile.id)
        )
        migratedProfiles[defaultProfileIndex] = migratedDefaultProfile

        return migratedProfiles
    }

    private func migrateLegacySettingsIfNeeded() throws {
        let rawData = try Data(contentsOf: environment.settingsFileURL)
        let rawJSONObject = try JSONSerialization.jsonObject(with: rawData)
        let rawDictionary = rawJSONObject as? [String: Any]
        let isMissingPrefixIndicatorToggle = rawDictionary?["showPrefixIndicatorOverlay"] == nil
        let usesLegacyBottomPlacement = (rawDictionary?["prefixIndicatorPlacement"] as? String) == PrefixIndicatorPlacement.bottom.rawValue

        guard (isMissingPrefixIndicatorToggle && settings.capsTapToggleThresholdMilliseconds == 100) || usesLegacyBottomPlacement else {
            return
        }

        if isMissingPrefixIndicatorToggle && settings.capsTapToggleThresholdMilliseconds == 100 {
            settings = settings.normalizedCapsTapToggleThreshold(AppSettings.default.capsTapToggleThresholdMilliseconds)
            logger.info("Migrated legacy Caps tap threshold from 100 ms to new default 200 ms.")
        }

        if usesLegacyBottomPlacement {
            settings = settings.withPrefixIndicatorPlacement(.right)
            logger.info("Migrated legacy bottom overlay placement to right placement.")
        }

        try settingsStore.save(settings)
    }

    private func syncLaunchAtLoginStatusWithSettings() throws {
        let actualStatus = launchAtLoginManager.refreshStatus()
        launchAtLoginStatus = actualStatus

        let normalizedSettings = settings.withLaunchAtLoginEnabled(actualStatus.isEnabledLike)

        guard normalizedSettings != settings else {
            return
        }

        settings = normalizedSettings
        try settingsStore.save(normalizedSettings)
    }

    private func updateActiveProfile(
        reason: String,
        mutation: (inout Profile) throws -> Bool
    ) {
        guard activeProfileID != Profile.default.id else {
            lastErrorMessage = "默认方案的按键映射不可直接修改，请复制后再编辑。"
            logger.error("Blocked mutation on default profile mappings.")
            return
        }

        guard let profileIndex = profiles.firstIndex(where: { $0.id == activeProfileID }) else {
            lastErrorMessage = "找不到当前激活的配置方案，无法保存修改。"
            return
        }

        do {
            var updatedProfile = profiles[profileIndex]
            let didChange = try mutation(&updatedProfile)

            guard didChange else {
                return
            }

            try profileLoader.saveProfile(
                updatedProfile,
                to: environment.profileFileURL(for: updatedProfile.id)
            )
            profiles[profileIndex] = updatedProfile
            lastErrorMessage = nil
            refreshOverlayIfNeeded()

            logger.info("\(reason, privacy: .public)")
        } catch {
            if let mutationError = error as? ActiveProfileMutationError {
                lastErrorMessage = mutationError.errorDescription
            } else {
                lastErrorMessage = error.localizedDescription
            }
            logger.error("Failed to mutate active profile: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func applyThemePreference(_ themePreference: AppThemePreference) {
        appThemeController.apply(themePreference)
    }

    private func handleAccessibilityPermissionPromptDidClose() {
        isAccessibilityPermissionPromptPresented = false
        restoreAccessoryActivationPolicyIfNeeded()
    }

    private func restoreAccessoryActivationPolicyIfNeeded() {
        guard !isSettingsWindowPresented,
              !isShortcutTrainerWindowPresented,
              !isAccessibilityPermissionPromptPresented,
              !isUpdateWindowPresented else {
            return
        }

        NSApplication.shared.setActivationPolicy(.accessory)
    }

    private func refreshOverlayIfNeeded() {
        guard settings.showPrefixIndicatorOverlay, isPrefixActive else {
            return
        }

        prefixIndicatorController.update(
            isActive: true,
            routingMode: prefixRoutingMode,
            profileName: activeProfileName,
            helpEntries: prefixIndicatorHelpEntries,
            placement: prefixIndicatorPlacement,
            opacityPercent: prefixIndicatorOpacityPercent
        )
    }

    private func handleHighlightedTriggerChanged(_ triggerSignature: String?) {
        guard highlightedPrefixTriggerSignature != triggerSignature else {
            return
        }

        highlightedPrefixTriggerSignature = triggerSignature
        refreshOverlayIfNeeded()
    }

    private func orderedProfiles(_ rawProfiles: [Profile]) -> [Profile] {
        guard !rawProfiles.isEmpty else {
            return []
        }

        let profilesByID = Dictionary(uniqueKeysWithValues: rawProfiles.map { ($0.id, $0) })
        var orderedProfiles: [Profile] = []
        var seenIDs = Set<String>()

        for profileID in settings.profileOrderIds {
            guard let profile = profilesByID[profileID], seenIDs.insert(profileID).inserted else {
                continue
            }

            orderedProfiles.append(profile)
        }

        for profile in rawProfiles where seenIDs.insert(profile.id).inserted {
            orderedProfiles.append(profile)
        }

        return orderedProfiles
    }

    private func isDuplicateProfileName(_ profileName: String, excludingProfileID: String? = nil) -> Bool {
        profiles.contains { existingProfile in
            guard existingProfile.id != excludingProfileID else {
                return false
            }

            return existingProfile.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(profileName) == .orderedSame
        }
    }

}

private enum ActiveProfileMutationError: LocalizedError {
    case mappingNotFound

    var errorDescription: String? {
        switch self {
        case .mappingNotFound:
            return "找不到需要更新的按键映射。"
        }
    }
}

enum StartupState: String {
    case idle
    case starting
    case running
    case failed

    var displayName: String {
        switch self {
        case .idle:
            return "未启动"
        case .starting:
            return "启动中"
        case .running:
            return "运行中"
        case .failed:
            return "启动失败"
        }
    }
}

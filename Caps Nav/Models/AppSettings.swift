import Foundation

struct AppSettings: Codable, Equatable {
    var activeProfileId: String
    var profileOrderIds: [String]
    var isAppEnabled: Bool
    var toggleAppShortcut: Shortcut?
    var themePreference: AppThemePreference
    var launchAtLogin: Bool
    var showMenuBarIcon: Bool
    var menuBarIconStyle: MenuBarIconStyle
    var showPrefixIndicatorOverlay: Bool
    var prefixIndicatorPlacement: PrefixIndicatorPlacement
    var prefixIndicatorOpacityPercent: Int
    var capsTapToggleThresholdMilliseconds: Int
    var hasCompletedOnboarding: Bool

    init(
        activeProfileId: String,
        profileOrderIds: [String],
        isAppEnabled: Bool,
        toggleAppShortcut: Shortcut?,
        themePreference: AppThemePreference,
        launchAtLogin: Bool,
        showMenuBarIcon: Bool,
        menuBarIconStyle: MenuBarIconStyle,
        showPrefixIndicatorOverlay: Bool,
        prefixIndicatorPlacement: PrefixIndicatorPlacement,
        prefixIndicatorOpacityPercent: Int,
        capsTapToggleThresholdMilliseconds: Int,
        hasCompletedOnboarding: Bool
    ) {
        self.activeProfileId = activeProfileId
        self.profileOrderIds = Self.normalizedProfileOrderIds(profileOrderIds)
        self.isAppEnabled = isAppEnabled
        self.toggleAppShortcut = toggleAppShortcut
        self.themePreference = themePreference
        self.launchAtLogin = launchAtLogin
        self.showMenuBarIcon = showMenuBarIcon
        self.menuBarIconStyle = Self.normalizedMenuBarIconStyle(menuBarIconStyle)
        self.showPrefixIndicatorOverlay = showPrefixIndicatorOverlay
        self.prefixIndicatorPlacement = Self.normalizedPrefixIndicatorPlacement(prefixIndicatorPlacement)
        self.prefixIndicatorOpacityPercent = Self.clampPrefixIndicatorOpacityPercent(prefixIndicatorOpacityPercent)
        self.capsTapToggleThresholdMilliseconds = Self.clampCapsTapToggleThreshold(capsTapToggleThresholdMilliseconds)
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    static let `default` = AppSettings(
        activeProfileId: "default",
        profileOrderIds: [],
        isAppEnabled: true,
        toggleAppShortcut: nil,
        themePreference: .system,
        launchAtLogin: false,
        showMenuBarIcon: true,
        menuBarIconStyle: .defaultKeyboard,
        showPrefixIndicatorOverlay: true,
        prefixIndicatorPlacement: .right,
        prefixIndicatorOpacityPercent: 82,
        capsTapToggleThresholdMilliseconds: 200,
        hasCompletedOnboarding: false
    )

    enum CodingKeys: String, CodingKey {
        case activeProfileId
        case profileOrderIds
        case isAppEnabled
        case toggleAppShortcut
        case themePreference
        case launchAtLogin
        case showMenuBarIcon
        case menuBarIconStyle
        case showPrefixIndicatorOverlay
        case prefixIndicatorPlacement
        case prefixIndicatorOpacityPercent
        case capsTapToggleThresholdMilliseconds
        case hasCompletedOnboarding
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            activeProfileId: try container.decodeIfPresent(String.self, forKey: .activeProfileId) ?? Self.default.activeProfileId,
            profileOrderIds: try container.decodeIfPresent([String].self, forKey: .profileOrderIds) ?? Self.default.profileOrderIds,
            isAppEnabled: try container.decodeIfPresent(Bool.self, forKey: .isAppEnabled) ?? Self.default.isAppEnabled,
            toggleAppShortcut: try container.decodeIfPresent(Shortcut.self, forKey: .toggleAppShortcut) ?? Self.default.toggleAppShortcut,
            themePreference: try container.decodeIfPresent(AppThemePreference.self, forKey: .themePreference) ?? Self.default.themePreference,
            launchAtLogin: try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? Self.default.launchAtLogin,
            showMenuBarIcon: try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? Self.default.showMenuBarIcon,
            menuBarIconStyle: try container.decodeIfPresent(MenuBarIconStyle.self, forKey: .menuBarIconStyle) ?? Self.default.menuBarIconStyle,
            showPrefixIndicatorOverlay: try container.decodeIfPresent(Bool.self, forKey: .showPrefixIndicatorOverlay) ?? Self.default.showPrefixIndicatorOverlay,
            prefixIndicatorPlacement: try container.decodeIfPresent(PrefixIndicatorPlacement.self, forKey: .prefixIndicatorPlacement) ?? Self.default.prefixIndicatorPlacement,
            prefixIndicatorOpacityPercent: try container.decodeIfPresent(Int.self, forKey: .prefixIndicatorOpacityPercent) ?? Self.default.prefixIndicatorOpacityPercent,
            capsTapToggleThresholdMilliseconds: try container.decodeIfPresent(Int.self, forKey: .capsTapToggleThresholdMilliseconds) ?? Self.default.capsTapToggleThresholdMilliseconds,
            hasCompletedOnboarding: try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? Self.default.hasCompletedOnboarding
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(activeProfileId, forKey: .activeProfileId)
        try container.encode(profileOrderIds, forKey: .profileOrderIds)
        try container.encode(isAppEnabled, forKey: .isAppEnabled)
        try container.encode(toggleAppShortcut, forKey: .toggleAppShortcut)
        try container.encode(themePreference, forKey: .themePreference)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(showMenuBarIcon, forKey: .showMenuBarIcon)
        try container.encode(menuBarIconStyle, forKey: .menuBarIconStyle)
        try container.encode(showPrefixIndicatorOverlay, forKey: .showPrefixIndicatorOverlay)
        try container.encode(prefixIndicatorPlacement, forKey: .prefixIndicatorPlacement)
        try container.encode(prefixIndicatorOpacityPercent, forKey: .prefixIndicatorOpacityPercent)
        try container.encode(capsTapToggleThresholdMilliseconds, forKey: .capsTapToggleThresholdMilliseconds)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
    }

    func normalizedCapsTapToggleThreshold(_ value: Int) -> AppSettings {
        var copy = self
        copy.capsTapToggleThresholdMilliseconds = Self.clampCapsTapToggleThreshold(value)
        return copy
    }

    func withPrefixIndicatorOverlayEnabled(_ isEnabled: Bool) -> AppSettings {
        var copy = self
        copy.showPrefixIndicatorOverlay = isEnabled
        return copy
    }

    func withAppEnabled(_ isEnabled: Bool) -> AppSettings {
        var copy = self
        copy.isAppEnabled = isEnabled
        return copy
    }

    func withToggleAppShortcut(_ shortcut: Shortcut?) -> AppSettings {
        var copy = self
        copy.toggleAppShortcut = shortcut
        return copy
    }

    func withPrefixIndicatorPlacement(_ placement: PrefixIndicatorPlacement) -> AppSettings {
        var copy = self
        copy.prefixIndicatorPlacement = Self.normalizedPrefixIndicatorPlacement(placement)
        return copy
    }

    func withPrefixIndicatorOpacityPercent(_ opacityPercent: Int) -> AppSettings {
        var copy = self
        copy.prefixIndicatorOpacityPercent = Self.clampPrefixIndicatorOpacityPercent(opacityPercent)
        return copy
    }

    func withProfileOrderIds(_ profileOrderIds: [String]) -> AppSettings {
        var copy = self
        copy.profileOrderIds = Self.normalizedProfileOrderIds(profileOrderIds)
        return copy
    }

    func withLaunchAtLoginEnabled(_ isEnabled: Bool) -> AppSettings {
        var copy = self
        copy.launchAtLogin = isEnabled
        return copy
    }

    func withThemePreference(_ themePreference: AppThemePreference) -> AppSettings {
        var copy = self
        copy.themePreference = themePreference
        return copy
    }

    func withMenuBarIconStyle(_ menuBarIconStyle: MenuBarIconStyle) -> AppSettings {
        var copy = self
        copy.menuBarIconStyle = Self.normalizedMenuBarIconStyle(menuBarIconStyle)
        return copy
    }

    func withOnboardingCompleted(_ hasCompleted: Bool) -> AppSettings {
        var copy = self
        copy.hasCompletedOnboarding = hasCompleted
        return copy
    }

    private static func clampCapsTapToggleThreshold(_ value: Int) -> Int {
        max(value, 0)
    }

    private static func clampPrefixIndicatorOpacityPercent(_ value: Int) -> Int {
        min(max(value, 20), 100)
    }

    private static func normalizedPrefixIndicatorPlacement(_ placement: PrefixIndicatorPlacement) -> PrefixIndicatorPlacement {
        placement == .bottom ? .top : placement
    }

    private static func normalizedMenuBarIconStyle(_ menuBarIconStyle: MenuBarIconStyle) -> MenuBarIconStyle {
        menuBarIconStyle == .prefixFlow ? .navigationTag : menuBarIconStyle
    }

    private static func normalizedProfileOrderIds(_ profileOrderIds: [String]) -> [String] {
        var seen = Set<String>()
        return profileOrderIds.compactMap { profileID in
            guard seen.insert(profileID).inserted else {
                return nil
            }

            return profileID
        }
    }
}

enum AppThemePreference: String, Codable, CaseIterable, Equatable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return "随系统"
        case .light:
            return "亮色"
        case .dark:
            return "暗色"
        }
    }

    var symbolName: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.stars.fill"
        }
    }

    var helperText: String {
        switch self {
        case .system:
            return "默认选项，跟随 macOS 当前外观自动切换。"
        case .light:
            return "始终使用亮色界面。"
        case .dark:
            return "始终使用暗色界面。"
        }
    }
}

enum MenuBarIconStyle: String, Codable, CaseIterable, Equatable, Identifiable {
    case defaultKeyboard
    case filledKeyboard
    case shortcutKeyboard
    case capsLock
    case capsLockFilled
    case commandKey
    case prefixFlow
    case monogram
    case navigationTag
    case homeRowTag

    static var allCases: [MenuBarIconStyle] {
        [
            .defaultKeyboard,
            .filledKeyboard,
            .shortcutKeyboard,
            .capsLock,
            .capsLockFilled,
            .commandKey,
            .monogram,
            .navigationTag,
            .homeRowTag
        ]
    }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .defaultKeyboard:
            return "默认"
        case .filledKeyboard:
            return "实心"
        case .shortcutKeyboard:
            return "快捷键"
        case .capsLock:
            return "Caps"
        case .capsLockFilled:
            return "Caps 实心"
        case .commandKey:
            return "Command"
        case .prefixFlow:
            return "Caps + 方向"
        case .monogram:
            return "CN 字标"
        case .navigationTag:
            return "导航字标"
        case .homeRowTag:
            return "ES 主键区"
        }
    }

    var glyphKind: MenuBarIconGlyphKind {
        switch self {
        case .defaultKeyboard:
            return .symbol("keyboard")
        case .filledKeyboard:
            return .symbol("keyboard.fill")
        case .shortcutKeyboard:
            return .symbol("keyboard.badge.ellipsis")
        case .capsLock:
            return .symbol("capslock")
        case .capsLockFilled:
            return .symbol("capslock.fill")
        case .commandKey:
            return .symbol("command")
        case .prefixFlow:
            return .overlay(base: "capslock.fill", badge: "chevron.right.circle.fill")
        case .monogram:
            return .capsuleText("CN")
        case .navigationTag:
            return .capsuleText("N>")
        case .homeRowTag:
            return .capsuleText("ES")
        }
    }

    var helperText: String {
        switch self {
        case .defaultKeyboard:
            return "使用当前这套线框键盘图标。"
        case .filledKeyboard:
            return "使用更饱满的实心键盘图标。"
        case .shortcutKeyboard:
            return "更强调“快捷键层”的状态栏图标。"
        case .capsLock:
            return "更直接突出 Caps Lock 作为前缀键。"
        case .capsLockFilled:
            return "突出 Caps Lock，同时视觉更醒目。"
        case .commandKey:
            return "使用更简洁的 Command 风格图标。"
        case .prefixFlow:
            return "用 Caps 键加方向徽标来强调“进入导航层”的感觉。"
        case .monogram:
            return "使用更简洁的 Caps Nav 字标风格。"
        case .navigationTag:
            return "使用更偏“导航层”语义的简洁字标。"
        case .homeRowTag:
            return "用 ESDF 主键区意象来强调主键区导航。"
        }
    }
}

enum MenuBarIconGlyphKind: Equatable {
    case symbol(String)
    case overlay(base: String, badge: String)
    case capsuleText(String)
}

enum PrefixIndicatorPlacement: String, Codable, CaseIterable, Equatable, Identifiable {
    case top
    case bottom
    case left
    case right

    static var allCases: [PrefixIndicatorPlacement] {
        [.top, .left, .right]
    }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .top:
            return "顶部"
        case .bottom:
            return "底部"
        case .left:
            return "左侧"
        case .right:
            return "右侧"
        }
    }

    var symbolName: String {
        switch self {
        case .top:
            return "rectangle.topthird.inset.filled"
        case .bottom:
            return "rectangle.bottomthird.inset.filled"
        case .left:
            return "rectangle.leadingthird.inset.filled"
        case .right:
            return "rectangle.trailingthird.inset.filled"
        }
    }
}

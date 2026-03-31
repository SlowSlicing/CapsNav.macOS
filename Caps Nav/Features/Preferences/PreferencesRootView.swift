import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

private enum SettingsPane: String, CaseIterable, Identifiable {
    case overview
    case keyboard
    case overlay
    case profiles
    case statistics
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            return "概览"
        case .keyboard:
            return "键盘"
        case .overlay:
            return "悬浮提示"
        case .profiles:
            return "配置方案"
        case .statistics:
            return "统计"
        case .advanced:
            return "高级"
        }
    }

    var subtitle: String {
        switch self {
        case .overview:
            return "运行状态、权限与最近一次命中"
        case .keyboard:
            return "Caps Lock 前缀键与短按回退设置"
        case .overlay:
            return "按住 Caps Lock 时的状态提示与帮助信息"
        case .profiles:
            return "当前激活配置方案与映射列表"
        case .statistics:
            return "使用统计与常用映射分析"
        case .advanced:
            return "数据目录与运行时路径"
        }
    }

    var symbolName: String {
        switch self {
        case .overview:
            return "rectangle.stack.badge.person.crop"
        case .keyboard:
            return "keyboard.fill"
        case .overlay:
            return "sparkles.rectangle.stack.fill"
        case .profiles:
            return "square.grid.2x2.fill"
        case .statistics:
            return "chart.bar.fill"
        case .advanced:
            return "internaldrive.fill"
        }
    }
}

private let settingsMappingEffectPreviewCoordinateSpaceName = "settingsMappingEffectPreviewCoordinateSpace"

private struct SettingsMappingEffectFloatingPreview: Equatable {
    let id: String
    let output: Output
}

private struct SettingsMappingEffectTriggerFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct PreferencesRootView: View {
    @ObservedObject var appBootstrap: AppBootstrap

    @State private var selectedPane: SettingsPane = .overview
    @FocusState private var isThresholdFieldFocused: Bool
    @State private var thresholdInput = ""
    @State private var draftMappings: [SettingsDraftMapping] = []
    @State private var profileNameSheetContext: SettingsProfileNameSheetContext?
    @State private var shortcutSheetContext: SettingsShortcutSheetContext?
    @State private var draggingProfileID: String?
    @State private var draggingHoverTargetProfileID: String?
    @State private var mappingEffectPreview: SettingsMappingEffectFloatingPreview?
    @State private var mappingEffectTriggerFrames: [String: CGRect] = [:]
    @State private var mappingEffectPreviewCardSize: CGSize = .zero
    @State private var hoveredMappingEffectTriggerID: String?
    @State private var hoveredMappingEffectPreviewID: String?
    @State private var mappingEffectPreviewDismissWorkItem: DispatchWorkItem?

    private let twoColumnGrid = [
        GridItem(.flexible(minimum: 320), spacing: 18, alignment: .top),
        GridItem(.flexible(minimum: 320), spacing: 18, alignment: .top)
    ]
    private let profileSelectionGrid = [
        GridItem(.adaptive(minimum: 220, maximum: 260), spacing: 12, alignment: .top)
    ]
    private let mappingKeyColumnWidth: CGFloat = 150
    private let mappingActionColumnWidth: CGFloat = 300
    private let mappingEffectColumnWidth: CGFloat = 96
    private let mappingOperationColumnWidth: CGFloat = 96

    var body: some View {
        ZStack {
            SettingsBackgroundView()

            VStack(alignment: .leading, spacing: 24) {
                SettingsHeroHeader(
                    activeProfileName: appBootstrap.activeProfileName,
                    startupState: appBootstrap.startupState.displayName,
                    accessibilityStatus: appBootstrap.accessibilityStatus.displayName
                )

                SettingsPaneSelector(
                    selectedPane: $selectedPane,
                    onSelect: {
                        dismissEditing()
                    }
                )

                currentPaneContent
            }
            .padding(28)

            mappingEffectPreviewOverlay
        }
        .coordinateSpace(name: settingsMappingEffectPreviewCoordinateSpaceName)
        .onPreferenceChange(SettingsMappingEffectTriggerFramePreferenceKey.self) { frames in
            mappingEffectTriggerFrames = frames
        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismissEditing()
        }
        .navigationTitle("Caps Nav 设置")
        .background(
            SettingsWindowConfigurator(minSize: NSSize(width: 1160, height: 780))
        )
        .sheet(item: $profileNameSheetContext) { context in
            SettingsProfileNameSheet(
                context: context,
                onSubmit: { profileName in
                    dismissEditing()
                    switch context.mode {
                    case .create:
                        return appBootstrap.createProfileFromDefault(named: profileName)
                    case let .duplicate(profileID, _):
                        return appBootstrap.duplicateProfile(profileID: profileID, named: profileName)
                    case let .rename(profileID):
                        return appBootstrap.renameProfile(profileID: profileID, to: profileName)
                    }
                }
            )
        }
        .sheet(item: $shortcutSheetContext) { context in
            SettingsShortcutSheet(
                context: context,
                onSubmit: { shortcut in
                    dismissEditing()
                    saveShortcut(shortcut, for: context)
                }
            )
        }
        .onAppear {
            syncThresholdInput()
        }
        .onDisappear {
            commitThresholdInput()
        }
        .onChange(of: appBootstrap.capsTapToggleThresholdMilliseconds) { _ in
            guard !isThresholdFieldFocused else {
                return
            }

            syncThresholdInput()
        }
        .onChange(of: isThresholdFieldFocused) { isFocused in
            if !isFocused {
                commitThresholdInput()
            }
        }
        .onChange(of: selectedPane) { newPane in
            clearMappingEffectPreview()

            if newPane != .profiles {
                clearProfileDrafts()
            }
        }
        .onChange(of: appBootstrap.activeProfileID) { _ in
            clearMappingEffectPreview()
            clearProfileDrafts()
        }
    }

    private var currentPaneContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsPaneLead(
                    title: selectedPane.title,
                    subtitle: selectedPane.subtitle
                )

                switch selectedPane {
                case .overview:
                    overviewPage
                case .keyboard:
                    keyboardPage
                case .overlay:
                    overlayPage
                case .profiles:
                    profilesPage
                case .statistics:
                    StatisticsView(appBootstrap: appBootstrap)
                case .advanced:
                    advancedPage
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 20)
            .contentShape(Rectangle())
            .onTapGesture {
                dismissEditing()
            }
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var mappingEffectPreviewOverlay: some View {
        GeometryReader { geometry in
            if let preview = mappingEffectPreview,
               let triggerFrame = mappingEffectTriggerFrames[preview.id] {
                let cardSize = effectiveMappingEffectPreviewCardSize(for: preview.output)
                let placement = SettingsMappingEffectPreviewLayout.placement(
                    triggerFrame: triggerFrame,
                    cardSize: cardSize,
                    containerBounds: CGRect(origin: .zero, size: geometry.size)
                )

                SettingsMappingEffectHoverCard(output: preview.output)
                    .background(
                        SettingsPreviewCardSizeReader(size: $mappingEffectPreviewCardSize)
                    )
                    .position(
                        x: placement.origin.x + (cardSize.width / 2),
                        y: placement.origin.y + (cardSize.height / 2)
                    )
                    .transition(
                        .opacity.combined(
                            with: .scale(
                                scale: 0.97,
                                anchor: placement.direction == .below ? .topTrailing : .bottomTrailing
                            )
                        )
                    )
                    .zIndex(600)
                    .allowsHitTesting(true)
                    .onHover { hovering in
                        handleMappingEffectPreviewCardHover(previewID: preview.id, isHovering: hovering)
                    }
            }
        }
    }

    private var overviewPage: some View {
        LazyVGrid(columns: twoColumnGrid, spacing: 18) {
            SettingsCard(
                title: "运行状态",
                symbolName: "waveform.path.ecg.rectangle",
                hint: "用于快速确认 App 是否启动成功、当前激活的是哪个配置方案，以及最近一次实际命中的映射。"
            ) {
                SettingsToggleRow(
                    title: "启用 Caps Nav",
                    subtitle: appBootstrap.operationalState.displayName,
                    isOn: Binding(
                        get: { appBootstrap.isAppEnabled },
                        set: {
                            dismissEditing()
                            appBootstrap.updateAppEnabled(to: $0)
                        }
                    ),
                    tint: CapsNavTheme.accentStrong
                )

                SettingsValueRow(
                    title: "实际运行状态",
                    value: appBootstrap.operationalState.displayName,
                    tone: operationalStateTone
                )
                SettingsValueRow(title: "启动状态", value: appBootstrap.startupState.displayName, tone: .accent)
                SettingsValueRow(title: "当前配置方案", value: appBootstrap.activeProfileName)
                SettingsValueRow(title: "前缀工作模式", value: appBootstrap.prefixRoutingMode.displayName)
                SettingsValueRow(title: "前缀状态", value: appBootstrap.isPrefixActive ? "按下中" : "已松开")
                SettingsValueRow(
                    title: "全局开关快捷键",
                    value: appBootstrap.globalToggleHotKeyRegistrationStatus.displayName,
                    tone: appBootstrap.toggleAppShortcut == nil ? .neutral : .accent
                )
                SettingsValueRow(title: "最近一次命中", value: appBootstrap.lastResolvedActionDescription)

                VStack(alignment: .leading, spacing: 10) {
                    Text("全局开关快捷键")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textPrimary)

                    HStack(spacing: 10) {
                        SettingsMenuPill(
                            title: appBootstrap.toggleAppShortcut?.userFacingDescription ?? "未设置",
                            symbolName: "command"
                        )

                        Button(appBootstrap.toggleAppShortcut == nil ? "设置快捷键" : "修改快捷键") {
                            openToggleAppShortcutSheet()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(CapsNavTheme.accentStrong)

                        if appBootstrap.toggleAppShortcut != nil {
                            Button("清空") {
                                dismissEditing()
                                appBootstrap.updateToggleAppShortcut(to: nil)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Text("这个快捷键会在任何前台应用中切换 Caps Nav 的启用/暂停状态。为了降低误触，至少包含一个修饰键。")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let lastErrorMessage = appBootstrap.lastErrorMessage {
                    SettingsInlineNotice(
                        text: lastErrorMessage,
                        tone: .danger
                    )
                }
            }

            SettingsCard(
                title: "权限与激活",
                symbolName: "lock.shield.fill",
                hint: "Caps Nav 的全局事件监听、按键拦截和快捷键重发都依赖 Accessibility 权限。"
            ) {
                SettingsValueRow(
                    title: "辅助功能权限",
                    value: appBootstrap.accessibilityStatus.displayName,
                    tone: appBootstrap.accessibilityStatus == .trusted ? .success : .warning
                )

                HStack(spacing: 10) {
                    Button("检查权限") {
                        dismissEditing()
                        appBootstrap.refreshAccessibilityStatus()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CapsNavTheme.accentStrong)

                    if appBootstrap.accessibilityStatus != .trusted {
                        Button("获取辅助功能权限") {
                            dismissEditing()
                            appBootstrap.requestAccessibilityPermission()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                SettingsInlineNotice(
                    text: "打开设置窗口时，Caps Nav 会临时进入前台 App 模式，以便出现在 Dock 和 Cmd + Tab 中。",
                    tone: .accent
                )
            }

            SettingsCard(
                title: "快捷键练习",
                symbolName: "gamecontroller.fill",
                hint: "训练题目会直接读取当前激活配置方案里的映射，帮助你用更低成本建立 Caps Lock 前缀键的肌肉记忆。"
            ) {
                SettingsValueRow(title: "当前题库来源", value: appBootstrap.activeProfileName, tone: .accent)
                SettingsValueRow(title: "练习模式", value: "认键练习、连招挑战")

                SettingsInlineNotice(
                    text: "适合第一次熟悉键位，也适合切换新配置方案后快速复习。训练窗口支持独立打开，不会打断当前设置页。",
                    tone: .accent
                )

                Button("打开快捷键练习") {
                    dismissEditing()
                    appBootstrap.openShortcutTrainerWindow()
                }
                .buttonStyle(.borderedProminent)
                .tint(CapsNavTheme.accentStrong)
            }
        }
    }

    private var keyboardPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard(
                title: "Caps 短按回退",
                symbolName: "timer",
                hint: "当 Caps Lock 在设定阈值内按下立刻松开，且期间没有其他按键或修饰键交互时，会执行系统默认的大小写切换。输入为空、非法或负数时，失焦后会恢复到默认值 200 ms。"
            ) {
                HStack(alignment: .center, spacing: 12) {
                    SettingsValuePill(
                        title: "当前生效值",
                        value: thresholdDescription,
                        tone: appBootstrap.capsTapToggleThresholdMilliseconds == 0 ? .warning : .accent
                    )

                    Spacer(minLength: 0)
                }

                HStack(alignment: .center, spacing: 12) {
                    TextField("200", text: thresholdInputBinding)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(width: 120)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(CapsNavTheme.surfaceSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    isThresholdFieldFocused ? CapsNavTheme.accentStrong : CapsNavTheme.borderSoft,
                                    lineWidth: isThresholdFieldFocused ? 1.5 : 1
                                )
                        )
                        .focused($isThresholdFieldFocused)
                        .onSubmit {
                            commitThresholdInput()
                        }

                    Text("ms")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textSecondary)

                    Stepper {
                        EmptyView()
                    } onIncrement: {
                        dismissEditing()
                        appBootstrap.updateCapsTapToggleThresholdMilliseconds(
                            to: appBootstrap.capsTapToggleThresholdMilliseconds + 10
                        )
                        syncThresholdInput()
                    } onDecrement: {
                        dismissEditing()
                        appBootstrap.updateCapsTapToggleThresholdMilliseconds(
                            to: max(appBootstrap.capsTapToggleThresholdMilliseconds - 10, 0)
                        )
                        syncThresholdInput()
                    }
                    .labelsHidden()

                    Spacer(minLength: 0)
                }

                SettingsInlineNotice(
                    text: "输入框只接受大于等于 0 的整数；设为 0 ms 时，Caps 只作为前缀键使用。",
                    tone: .accent
                )
            }

            SettingsCard(
                title: "前缀键状态",
                symbolName: "arrow.triangle.branch",
                hint: "Caps Lock 是固定前缀键。App 会在后台确保按下与松开的识别稳定，用户使用时只需要把它理解成前缀键即可。"
            ) {
                SettingsValueRow(title: "识别模式", value: appBootstrap.prefixRoutingMode.displayName, tone: .accent)
                SettingsValueRow(title: "当前状态", value: appBootstrap.isPrefixActive ? "Caps Lock 正在按下" : "Caps Lock 已松开")
            }
        }
    }

    private var overlayPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard(
                title: "悬浮帮助框",
                symbolName: "sparkles.rectangle.stack",
                hint: "开启后，按住 Caps Lock 会显示状态和当前配置方案的前缀键位提示。关闭后只隐藏提示，不影响导航功能。"
            ) {
                Toggle(
                    isOn: Binding(
                        get: { appBootstrap.isPrefixIndicatorOverlayEnabled },
                        set: {
                            dismissEditing()
                            appBootstrap.updatePrefixIndicatorOverlayEnabled(to: $0)
                        }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("按住 Caps Lock 时显示悬浮帮助框")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textPrimary)

                        Text(appBootstrap.isPrefixIndicatorOverlayEnabled ? "当前已启用" : "当前已关闭")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textSecondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(CapsNavTheme.accentStrong)

                VStack(alignment: .leading, spacing: 10) {
                    Text("悬浮位置")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textPrimary)

                    SettingsPlacementSelector(
                        selectedPlacement: appBootstrap.prefixIndicatorPlacement,
                        onSelect: { placement in
                            dismissEditing()
                            appBootstrap.updatePrefixIndicatorPlacement(to: placement)
                        }
                    )

                    SettingsInlineNotice(
                        text: "默认放在右侧；小屏幕或分辨率较低时，左右侧会自动收窄并限制高度，避免超出屏幕。",
                        tone: .accent
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("背景透明度")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textPrimary)

                        Spacer(minLength: 0)

                        SettingsValuePill(
                            title: "当前",
                            value: "\(appBootstrap.prefixIndicatorOpacityPercent)%",
                            tone: .neutral
                        )
                    }

                    Slider(
                        value: Binding(
                            get: { Double(appBootstrap.prefixIndicatorOpacityPercent) },
                            set: {
                                dismissEditing()
                                appBootstrap.updatePrefixIndicatorOpacityPercent(to: Int($0.rounded()))
                            }
                        ),
                        in: 20...100,
                        step: 1
                    )
                    .tint(CapsNavTheme.accentStrong)

                    HStack {
                        Text("更通透")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textSecondary)

                        Spacer(minLength: 0)

                        Text("更清晰")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textSecondary)
                    }

                    SettingsInlineNotice(
                        text: "透明度会作用到整个悬浮帮助框，包括文字、徽标、背景和边框。范围 20% 到 100%，默认 82%。",
                        tone: .accent
                    )
                }
            }

            SettingsCard(
                title: "当前配置方案提示预览",
                symbolName: "list.bullet.rectangle.portrait",
                hint: "这里展示的是悬浮帮助框会使用的同一份键位说明。这里只做预览；如需修改，请到“配置方案”页编辑。"
            ) {
                if let activeProfile = appBootstrap.activeProfile {
                    HStack {
                        SettingsValuePill(title: "配置方案", value: activeProfile.name, tone: .accent)
                        SettingsValuePill(title: "映射数", value: "\(activeProfile.mappings.count)", tone: .neutral)
                        Spacer(minLength: 0)
                    }

                    LazyVGrid(columns: twoColumnGrid, spacing: 12) {
                        ForEach(activeProfile.mappings, id: \.trigger.signature) { mapping in
                            SettingsMappingPreviewRow(
                                triggerText: mapping.trigger.prefixIndicatorDisplayText,
                                descriptionText: mapping.displayDescription
                            )
                        }
                    }
                } else {
                    SettingsEmptyState(text: "当前还没有可用的配置方案。")
                }
            }
        }
    }

    private var profilesPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard(
                title: "激活配置方案",
                symbolName: "person.text.rectangle",
                hint: "这里只负责切换当前运行时使用的配置方案；后续可视化编辑器可以继续在这个分类里扩展。"
            ) {
                if appBootstrap.profiles.isEmpty {
                    SettingsEmptyState(text: "当前尚未加载任何配置方案。")
                } else {
                    HStack {
                        Spacer(minLength: 0)

                        Button {
                            dismissEditing()
                            profileNameSheetContext = SettingsProfileNameSheetContext(
                                mode: .create,
                                initialName: "",
                                existingNames: appBootstrap.profiles.map(\.name)
                            )
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))

                                Text("新增配置方案")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(CapsNavTheme.accentStrong)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(CapsNavTheme.accentSoft)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(CapsNavTheme.accentStrong.opacity(0.22), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    LazyVGrid(columns: profileSelectionGrid, alignment: .leading, spacing: 12) {
                        ForEach(appBootstrap.profiles) { profile in
                            SettingsProfileSelectionCard(
                                profile: profile,
                                isSelected: profile.id == appBootstrap.activeProfileID,
                                canRename: profile.id != Profile.default.id,
                                canDelete: profile.id != Profile.default.id && appBootstrap.profiles.count > 1,
                                onSelect: {
                                    dismissEditing()
                                    appBootstrap.switchActiveProfile(to: profile.id)
                                },
                                onRename: {
                                    dismissEditing()
                                    profileNameSheetContext = SettingsProfileNameSheetContext(
                                        mode: .rename(profileID: profile.id),
                                        initialName: profile.name,
                                        existingNames: appBootstrap.profiles
                                            .filter { $0.id != profile.id }
                                            .map(\.name)
                                    )
                                },
                                onDuplicate: {
                                    dismissEditing()
                                    profileNameSheetContext = SettingsProfileNameSheetContext(
                                        mode: .duplicate(profileID: profile.id, sourceName: profile.name),
                                        initialName: suggestedDuplicateProfileName(for: profile),
                                        existingNames: appBootstrap.profiles.map(\.name)
                                    )
                                },
                                onRevealInFinder: {
                                    dismissEditing()
                                    appBootstrap.openPathInFinder(
                                        appBootstrap.environment.profileFileURL(for: profile.id),
                                        revealInParent: true
                                    )
                                },
                                onDelete: {
                                    dismissEditing()
                                    appBootstrap.deleteProfile(profileID: profile.id)
                                }
                            )
                            .opacity(draggingProfileID == profile.id ? 0.72 : 1)
                            .onDrag {
                                draggingProfileID = profile.id
                                draggingHoverTargetProfileID = nil
                                return NSItemProvider(object: NSString(string: profile.id))
                            }
                            .onDrop(
                                of: [UTType.plainText],
                                delegate: SettingsProfileDropDelegate(
                                    targetProfileID: profile.id,
                                    draggingProfileID: $draggingProfileID,
                                    draggingHoverTargetProfileID: $draggingHoverTargetProfileID,
                                    onReorder: { draggedProfileID, targetProfileID in
                                        appBootstrap.reorderProfiles(
                                            draggedProfileID: draggedProfileID,
                                            to: targetProfileID
                                        )
                                    }
                                )
                            )
                        }
                    }
                    .animation(.spring(response: 0.24, dampingFraction: 0.86), value: appBootstrap.profiles.map(\.id))

                    SettingsInlineNotice(
                        text: "切换后，Caps 悬浮帮助和按键映射都会立即切到新的配置方案。支持拖拽排序，新的顺序会直接保存。",
                        tone: .accent
                    )
                }
            }

            SettingsCard(
                title: "按键映射",
                symbolName: "rectangle.split.3x1",
                hint: "这里维护当前激活配置方案里的映射关系。Caps Lock 固定作为前缀键；这里配置的是前缀后的触发键、对应内置功能或自定义快捷键，以及悬浮帮助框会读取的快捷键说明。"
            ) {
                if let activeProfile = appBootstrap.activeProfile {
                    let isActiveProfileReadOnly = activeProfile.id == Profile.default.id

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .center, spacing: 10) {
                            SettingsValuePill(title: "配置方案", value: activeProfile.name, tone: .accent)
                            SettingsValuePill(title: "映射数", value: "\(activeProfile.mappings.count)", tone: .neutral)

                            Spacer(minLength: 0)

                            if isActiveProfileReadOnly {
                                SettingsProfileMetaPill(text: "默认方案只读", isSelected: true)
                            } else {
                                Button {
                                    dismissEditing()
                                    draftMappings.insert(SettingsDraftMapping(), at: 0)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 11, weight: .bold))

                                        Text("新增快捷键")
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundStyle(CapsNavTheme.accentStrong)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(CapsNavTheme.accentSoft)
                                    )
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(CapsNavTheme.accentStrong.opacity(0.22), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if isActiveProfileReadOnly {
                            SettingsInlineNotice(
                                text: "默认方案用于提供稳定基线，当前只能查看，不能新增、修改或删除映射。如需自定义，请先复制成新的配置方案再编辑。",
                                tone: .warning
                            )
                        }

                        SettingsProfileEditorHeaderRow(
                            keyColumnWidth: mappingKeyColumnWidth,
                            actionColumnWidth: mappingActionColumnWidth,
                            effectColumnWidth: mappingEffectColumnWidth,
                            operationColumnWidth: mappingOperationColumnWidth
                        )

                        if !isActiveProfileReadOnly {
                            ForEach(draftMappings) { draft in
                                SettingsDraftMappingEditorRow(
                                    draft: draft,
                                    unavailableKeys: unavailableTriggerKeys(excludingDraftID: draft.id),
                                    keyColumnWidth: mappingKeyColumnWidth,
                                    actionColumnWidth: mappingActionColumnWidth,
                                    effectColumnWidth: mappingEffectColumnWidth,
                                    operationColumnWidth: mappingOperationColumnWidth,
                                    onPreviewHoverChanged: handleMappingEffectTriggerHover,
                                    onSelectKey: { selectedKey in
                                        updateDraftMapping(id: draft.id) { $0.key = selectedKey }
                                    },
                                    onSelectBuiltinAction: { action in
                                        updateDraftMapping(id: draft.id) {
                                            $0.output = .builtin(action: action)
                                        }
                                    },
                                    onEditShortcut: {
                                        openShortcutSheet(forDraftID: draft.id)
                                    },
                                    onSave: {
                                        saveDraftMapping(id: draft.id)
                                    },
                                    onDelete: {
                                        deleteDraftMapping(id: draft.id)
                                    }
                                )
                            }
                        }

                        ForEach(activeProfile.mappings, id: \.trigger.signature) { mapping in
                            SettingsPersistedMappingEditorRow(
                                mapping: mapping,
                                unavailableKeys: unavailableTriggerKeys(excludingTriggerSignature: mapping.trigger.signature),
                                keyColumnWidth: mappingKeyColumnWidth,
                                actionColumnWidth: mappingActionColumnWidth,
                                effectColumnWidth: mappingEffectColumnWidth,
                                operationColumnWidth: mappingOperationColumnWidth,
                                isReadOnly: isActiveProfileReadOnly,
                                onPreviewHoverChanged: handleMappingEffectTriggerHover,
                                onSelectKey: { selectedKey in
                                    dismissEditing()
                                    appBootstrap.updateActiveProfileMappingKey(
                                        forTriggerSignature: mapping.trigger.signature,
                                        to: selectedKey
                                    )
                                },
                                onSelectBuiltinAction: { action in
                                    dismissEditing()
                                    appBootstrap.updateActiveProfileMappingOutput(
                                        forTriggerSignature: mapping.trigger.signature,
                                        to: .builtin(action: action)
                                    )
                                },
                                onEditShortcut: {
                                    openShortcutSheet(forMapping: mapping)
                                },
                                onDelete: {
                                    dismissEditing()
                                    appBootstrap.deleteActiveProfileMapping(forTriggerSignature: mapping.trigger.signature)
                                }
                            )
                        }
                    }
                } else {
                    SettingsEmptyState(text: "未找到当前激活的配置方案。")
                }
            }
        }
    }

    private var advancedPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard(
                title: "外观与主题",
                symbolName: "paintbrush.pointed.fill",
                hint: "控制 Caps Nav 自身窗口与悬浮提示的外观模式。默认随系统；切换后会立即作用到设置页、权限窗口、关于窗口和悬浮提示。"
            ) {
                SettingsThemeSelector(
                    selectedThemePreference: appBootstrap.themePreference,
                    onSelect: { themePreference in
                        dismissEditing()
                        appBootstrap.updateThemePreference(to: themePreference)
                    }
                )

                SettingsInlineNotice(
                    text: "“随系统”会跟着 macOS 自动切换；“亮色”和“暗色”会强制覆盖当前应用的可见界面风格。",
                    tone: .accent
                )
            }

            SettingsCard(
                title: "状态栏图标",
                symbolName: "menubar.rectangle",
                hint: "控制菜单栏中的 Caps Nav 图标样式。切换后会立即刷新状态栏入口，不需要重启应用。"
            ) {
                SettingsMenuBarIconStyleSelector(
                    selectedStyle: appBootstrap.menuBarIconStyle,
                    onSelect: { menuBarIconStyle in
                        dismissEditing()
                        appBootstrap.updateMenuBarIconStyle(to: menuBarIconStyle)
                    }
                )

                SettingsInlineNotice(
                    text: "当前只切换状态栏入口图标样式，不影响 Dock、设置页或悬浮提示里的其他视觉元素。",
                    tone: .accent
                )
            }

            SettingsCard(
                title: "启动与登录项",
                symbolName: "power.circle.fill",
                hint: "开机自启属于应用级设置，行业里通常会放在通用或高级分类。这里开启后，Caps Nav 会在你登录 macOS 后自动启动。"
            ) {
                Toggle(
                    isOn: Binding(
                        get: { appBootstrap.isLaunchAtLoginEnabled },
                        set: {
                            dismissEditing()
                            appBootstrap.updateLaunchAtLoginEnabled(to: $0)
                        }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("登录 macOS 后自动启动 Caps Nav")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textPrimary)

                        Text(appBootstrap.launchAtLoginStatus.displayName)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textSecondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(CapsNavTheme.accentStrong)

                if appBootstrap.requiresLaunchAtLoginApproval {
                    HStack(spacing: 10) {
                        SettingsInlineNotice(
                            text: "系统已经记录了开机自启请求，但当前还需要你在“系统设置 -> 登录项”里批准。",
                            tone: .warning
                        )

                        Button("打开登录项设置") {
                            dismissEditing()
                            appBootstrap.openLaunchAtLoginSystemSettings()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            SettingsCard(
                title: "存储路径",
                symbolName: "folder.badge.gearshape",
                hint: "这些路径用于定位 settings.json 和配置方案数据，方便后续排查或手动编辑配置。"
            ) {
                SettingsPathRow(
                    title: "应用数据目录",
                    path: appBootstrap.environment.applicationSupportDirectoryURL.path,
                    buttonTitle: "打开目录",
                    buttonSymbolName: "folder",
                    action: {
                        dismissEditing()
                        appBootstrap.openPathInFinder(appBootstrap.environment.applicationSupportDirectoryURL)
                    }
                )
                SettingsPathRow(
                    title: "配置方案目录",
                    path: appBootstrap.environment.profilesDirectoryURL.path,
                    buttonTitle: "打开目录",
                    buttonSymbolName: "folder.badge.gearshape",
                    action: {
                        dismissEditing()
                        appBootstrap.openPathInFinder(appBootstrap.environment.profilesDirectoryURL)
                    }
                )
                SettingsPathRow(
                    title: "Settings 文件",
                    path: appBootstrap.environment.settingsFileURL.path,
                    buttonTitle: "定位文件",
                    buttonSymbolName: "scope",
                    action: {
                        dismissEditing()
                        appBootstrap.openPathInFinder(
                            appBootstrap.environment.settingsFileURL,
                            revealInParent: true
                        )
                    }
                )
            }

            SettingsCard(
                title: "引导教程",
                symbolName: "graduationcap.fill",
                hint: "重新播放首次启动引导教程，帮助回顾 Caps Nav 的核心用法和配置流程。"
            ) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("重新播放引导教程")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textPrimary)

                        Text("重新查看 Caps Nav 的用法介绍与权限设置引导")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textSecondary)
                    }

                    Spacer()

                    Button {
                        dismissEditing()
                        appBootstrap.showOnboarding()
                    } label: {
                        Label("播放引导", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)
                }
            }

            SettingsCard(
                title: "当前运行上下文",
                symbolName: "gauge.open.with.lines.needle.33percent",
                hint: "这里保留运行时的一些即时信息，方便后续继续扩展日志、调试或诊断能力。"
            ) {
                SettingsValueRow(title: "启动状态", value: appBootstrap.startupState.displayName, tone: .accent)
                SettingsValueRow(title: "辅助功能权限", value: appBootstrap.accessibilityStatus.displayName)
                SettingsValueRow(title: "前缀工作模式", value: appBootstrap.prefixRoutingMode.displayName)
            }
        }
    }

    private var thresholdInputBinding: Binding<String> {
        Binding(
            get: { thresholdInput },
            set: { newValue in
                let filtered = newValue.filter(\.isNumber)
                thresholdInput = filtered
            }
        )
    }

    private var thresholdDescription: String {
        let value = appBootstrap.capsTapToggleThresholdMilliseconds
        return value == 0 ? "已关闭" : "\(value) ms"
    }

    private func syncThresholdInput() {
        thresholdInput = String(appBootstrap.capsTapToggleThresholdMilliseconds)
    }

    private func commitThresholdInput() {
        let fallbackValue = AppSettings.default.capsTapToggleThresholdMilliseconds
        let nextValue = Int(thresholdInput) ?? fallbackValue

        appBootstrap.updateCapsTapToggleThresholdMilliseconds(to: nextValue)
        syncThresholdInput()
    }

    private func suggestedDuplicateProfileName(for profile: Profile) -> String {
        let existingNames = Set(
            appBootstrap.profiles.map {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
        )
        let baseName = "\(profile.name) 副本"

        if !existingNames.contains(baseName.lowercased()) {
            return baseName
        }

        var suffix = 2
        while existingNames.contains("\(baseName) \(suffix)".lowercased()) {
            suffix += 1
        }

        return "\(baseName) \(suffix)"
    }

    private func dismissEditing() {
        clearMappingEffectPreview()
        isThresholdFieldFocused = false
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    private func handleMappingEffectTriggerHover(
        previewID: String,
        output: Output?,
        isHovering: Bool
    ) {
        mappingEffectPreviewDismissWorkItem?.cancel()

        guard let output else {
            return
        }

        if isHovering {
            hoveredMappingEffectTriggerID = previewID
            mappingEffectPreview = SettingsMappingEffectFloatingPreview(id: previewID, output: output)
            return
        }

        if hoveredMappingEffectTriggerID == previewID {
            hoveredMappingEffectTriggerID = nil
        }

        scheduleMappingEffectPreviewDismissalIfNeeded()
    }

    private func handleMappingEffectPreviewCardHover(previewID: String, isHovering: Bool) {
        mappingEffectPreviewDismissWorkItem?.cancel()

        if isHovering {
            hoveredMappingEffectPreviewID = previewID
            return
        }

        if hoveredMappingEffectPreviewID == previewID {
            hoveredMappingEffectPreviewID = nil
        }

        scheduleMappingEffectPreviewDismissalIfNeeded()
    }

    private func scheduleMappingEffectPreviewDismissalIfNeeded() {
        guard hoveredMappingEffectTriggerID == nil,
              hoveredMappingEffectPreviewID == nil else {
            return
        }

        let workItem = DispatchWorkItem {
            clearMappingEffectPreview()
        }
        mappingEffectPreviewDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: workItem)
    }

    private func clearMappingEffectPreview() {
        mappingEffectPreviewDismissWorkItem?.cancel()
        mappingEffectPreviewDismissWorkItem = nil
        hoveredMappingEffectTriggerID = nil
        hoveredMappingEffectPreviewID = nil
        mappingEffectPreview = nil
        mappingEffectPreviewCardSize = .zero
    }

    private func effectiveMappingEffectPreviewCardSize(for output: Output) -> CGSize {
        if mappingEffectPreviewCardSize != .zero {
            return mappingEffectPreviewCardSize
        }

        switch output {
        case .builtin:
            return CGSize(width: 360, height: 292)
        case .shortcut:
            return CGSize(width: 360, height: 228)
        }
    }

    private func clearProfileDrafts() {
        draftMappings.removeAll()
    }

    private func updateDraftMapping(id: UUID, mutation: (inout SettingsDraftMapping) -> Void) {
        guard let draftIndex = draftMappings.firstIndex(where: { $0.id == id }) else {
            return
        }

        mutation(&draftMappings[draftIndex])
    }

    private func deleteDraftMapping(id: UUID) {
        draftMappings.removeAll { $0.id == id }
    }

    private func saveDraftMapping(id: UUID) {
        guard let draft = draftMappings.first(where: { $0.id == id }),
              let normalizedKey = draft.normalizedKey,
              let output = draft.output else {
            return
        }

        let originalCount = appBootstrap.activeProfile?.mappings.count ?? 0
        appBootstrap.addActiveProfileMapping(
            key: normalizedKey,
            output: output,
            description: output.suggestedDescription
        )

        let updatedCount = appBootstrap.activeProfile?.mappings.count ?? 0
        if updatedCount > originalCount {
            deleteDraftMapping(id: id)
        }
    }

    private func openShortcutSheet(forDraftID draftID: UUID) {
        guard let draft = draftMappings.first(where: { $0.id == draftID }) else {
            return
        }

        dismissEditing()
        shortcutSheetContext = SettingsShortcutSheetContext(
            target: .draft(id: draftID),
            contextKind: .mappingOutput(triggerText: draft.normalizedKey.map { "+\($0)" }),
            initialShortcut: draft.output?.shortcutValue
        )
    }

    private func openShortcutSheet(forMapping mapping: Mapping) {
        dismissEditing()
        shortcutSheetContext = SettingsShortcutSheetContext(
            target: .persisted(triggerSignature: mapping.trigger.signature),
            contextKind: .mappingOutput(triggerText: mapping.trigger.prefixIndicatorDisplayText),
            initialShortcut: mapping.shortcut
        )
    }

    private func openToggleAppShortcutSheet() {
        dismissEditing()
        shortcutSheetContext = SettingsShortcutSheetContext(
            target: .appToggleShortcut,
            contextKind: .appToggle,
            initialShortcut: appBootstrap.toggleAppShortcut
        )
    }

    private func saveShortcut(_ shortcut: Shortcut, for context: SettingsShortcutSheetContext) {
        switch context.target {
        case let .draft(id):
            updateDraftMapping(id: id) {
                $0.output = .shortcut(shortcut)
            }
        case let .persisted(triggerSignature):
            appBootstrap.updateActiveProfileMappingOutput(
                forTriggerSignature: triggerSignature,
                to: .shortcut(shortcut)
            )
        case .appToggleShortcut:
            appBootstrap.updateToggleAppShortcut(to: shortcut)
        }
    }

    private func unavailableTriggerKeys(
        excludingTriggerSignature triggerSignature: String? = nil,
        excludingDraftID draftID: UUID? = nil
    ) -> Set<String> {
        var keys = Set<String>()

        if let activeProfile = appBootstrap.activeProfile {
            for mapping in activeProfile.mappings where mapping.trigger.signature != triggerSignature {
                keys.insert(mapping.trigger.key)
            }
        }

        for draft in draftMappings where draft.id != draftID {
            if let normalizedKey = draft.normalizedKey {
                keys.insert(normalizedKey)
            }
        }

        return keys
    }

}

private struct SettingsBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [CapsNavTheme.windowTop, CapsNavTheme.windowBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(CapsNavTheme.glowPrimary)
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .offset(x: -260, y: -190)

            Circle()
                .fill(CapsNavTheme.glowSecondary)
                .frame(width: 280, height: 280)
                .blur(radius: 95)
                .offset(x: 300, y: -240)
        }
    }
}

private struct SettingsHeroHeader: View {
    let activeProfileName: String
    let startupState: String
    let accessibilityStatus: String

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Caps Nav")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textPrimary)

                Text("把 Caps Lock 变成可靠的前缀导航键，同时保留可控的短按回退。")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textSecondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                SettingsValuePill(title: "配置方案", value: activeProfileName, tone: .accent)
                SettingsValuePill(title: "启动", value: startupState, tone: .neutral)
                SettingsValuePill(title: "权限", value: accessibilityStatus, tone: .neutral)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(CapsNavTheme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(CapsNavTheme.borderSoft.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: CapsNavTheme.cardShadow, radius: 24, x: 0, y: 14)
    }
}

private struct SettingsPaneSelector: View {
    @Binding var selectedPane: SettingsPane
    let onSelect: () -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(SettingsPane.allCases) { pane in
                    Button {
                        selectedPane = pane
                        onSelect()
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: pane.symbolName)
                                    .font(.system(size: 13, weight: .semibold))

                                Text(pane.title)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }

                            Text(pane.subtitle)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selectedPane == pane ? CapsNavTheme.textPrimary : CapsNavTheme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(width: 196, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(selectedPane == pane ? CapsNavTheme.accentSoft : CapsNavTheme.surfacePrimary.opacity(0.82))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    selectedPane == pane ? CapsNavTheme.accentStrong.opacity(0.65) : CapsNavTheme.borderSoft.opacity(0.85),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }
}

private struct SettingsPaneLead: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textPrimary)

            Text(subtitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textSecondary)
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let symbolName: String
    let hint: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(CapsNavTheme.accentSurface)
                        .frame(width: 36, height: 36)

                    Image(systemName: symbolName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(CapsNavTheme.accentStrong)
                }

                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textPrimary)

                if let hint {
                    SettingsHintIcon(text: hint)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(CapsNavTheme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(CapsNavTheme.borderSoft.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: CapsNavTheme.cardShadow.opacity(0.85), radius: 18, x: 0, y: 10)
    }
}

private struct SettingsHintIcon: View {
    let text: String
    @State private var isHovering = false

    var body: some View {
        Image(systemName: "exclamationmark.circle.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(CapsNavTheme.warning)
            .padding(4)
            .contentShape(Rectangle())
            .overlay(alignment: .leading) {
                if isHovering {
                    SettingsTooltipBubble(text: text)
                        .offset(x: 24, y: 0)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
                }
            }
            .zIndex(isHovering ? 10 : 0)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}

private struct SettingsTooltipBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(CapsNavTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(width: 300, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(CapsNavTheme.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(CapsNavTheme.borderSoft.opacity(0.92), lineWidth: 1)
            )
            .shadow(color: CapsNavTheme.cardShadow.opacity(1), radius: 14, x: 0, y: 10)
            .fixedSize(horizontal: false, vertical: true)
            .allowsHitTesting(false)
    }
}

private struct SettingsValueRow: View {
    enum Tone {
        case neutral
        case accent
        case success
        case warning
        case danger

        var foreground: Color {
            switch self {
            case .neutral:
                return CapsNavTheme.textPrimary
            case .accent:
                return CapsNavTheme.accentStrong
            case .success:
                return CapsNavTheme.success
            case .warning:
                return CapsNavTheme.warning
            case .danger:
                return CapsNavTheme.danger
            }
        }

        var background: Color {
            switch self {
            case .neutral:
                return CapsNavTheme.surfaceSecondary
            case .accent:
                return CapsNavTheme.accentSoft
            case .success:
                return CapsNavTheme.surfaceSecondary
            case .warning:
                return CapsNavTheme.surfaceSecondary
            case .danger:
                return CapsNavTheme.surfaceSecondary
            }
        }
    }

    let title: String
    let value: String
    var tone: Tone = .neutral

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textSecondary)

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(tone.foreground)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(tone.background)
                )
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    var tint: Color = CapsNavTheme.accentStrong

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textSecondary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textPrimary)
                }
            }

            Spacer(minLength: 0)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(tint)
        }
    }
}

private struct SettingsValuePill: View {
    let title: String
    let value: String
    let tone: SettingsValueRow.Tone

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textMuted)

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(tone.foreground)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tone.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(CapsNavTheme.borderSoft.opacity(0.7), lineWidth: 1)
        )
    }
}

private struct SettingsInlineNotice: View {
    let text: String
    let tone: SettingsValueRow.Tone

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tone.foreground)
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CapsNavTheme.surfaceSecondary.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(CapsNavTheme.borderSoft.opacity(0.8), lineWidth: 1)
        )
    }
}

private struct SettingsPlacementSelector: View {
    let selectedPlacement: PrefixIndicatorPlacement
    let onSelect: (PrefixIndicatorPlacement) -> Void

    private let grid = [
        GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 10, alignment: .top)
    ]

    var body: some View {
        LazyVGrid(columns: grid, alignment: .leading, spacing: 10) {
            ForEach(PrefixIndicatorPlacement.allCases) { placement in
                Button {
                    onSelect(placement)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: placement.symbolName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(selectedPlacement == placement ? CapsNavTheme.accentStrong : CapsNavTheme.textSecondary)

                        Text(placement.displayName)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(selectedPlacement == placement ? CapsNavTheme.textPrimary : CapsNavTheme.textSecondary)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selectedPlacement == placement ? CapsNavTheme.accentSoft : CapsNavTheme.surfaceSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                selectedPlacement == placement ? CapsNavTheme.accentStrong.opacity(0.6) : CapsNavTheme.borderSoft.opacity(0.85),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SettingsThemeSelector: View {
    let selectedThemePreference: AppThemePreference
    let onSelect: (AppThemePreference) -> Void

    private let grid = [
        GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 10, alignment: .top)
    ]

    var body: some View {
        LazyVGrid(columns: grid, alignment: .leading, spacing: 10) {
            ForEach(AppThemePreference.allCases) { themePreference in
                Button {
                    onSelect(themePreference)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: themePreference.symbolName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(
                                    selectedThemePreference == themePreference ? CapsNavTheme.accentStrong : CapsNavTheme.textSecondary
                                )

                            Text(themePreference.displayName)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(
                                    selectedThemePreference == themePreference ? CapsNavTheme.textPrimary : CapsNavTheme.textSecondary
                                )

                            Spacer(minLength: 0)
                        }

                        Text(themePreference.helperText)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selectedThemePreference == themePreference ? CapsNavTheme.accentSoft : CapsNavTheme.surfaceSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                selectedThemePreference == themePreference ? CapsNavTheme.accentStrong.opacity(0.6) : CapsNavTheme.borderSoft.opacity(0.85),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SettingsMenuBarIconStyleSelector: View {
    let selectedStyle: MenuBarIconStyle
    let onSelect: (MenuBarIconStyle) -> Void

    private let grid = [
        GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 10, alignment: .top)
    ]

    var body: some View {
        LazyVGrid(columns: grid, alignment: .leading, spacing: 10) {
            ForEach(MenuBarIconStyle.allCases) { style in
                Button {
                    onSelect(style)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            MenuBarIconGlyphView(
                                style: style,
                                tint: selectedStyle == style ? CapsNavTheme.accentStrong : CapsNavTheme.textSecondary,
                                symbolSize: 15
                            )
                            .frame(width: 42)

                            Text(style.displayName)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(selectedStyle == style ? CapsNavTheme.textPrimary : CapsNavTheme.textSecondary)

                            Spacer(minLength: 0)
                        }

                        Text(style.helperText)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selectedStyle == style ? CapsNavTheme.accentSoft : CapsNavTheme.surfaceSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                selectedStyle == style ? CapsNavTheme.accentStrong.opacity(0.6) : CapsNavTheme.borderSoft.opacity(0.85),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SettingsProfileIconButton: View {
    let title: String
    let symbolName: String
    let tint: Color
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(CapsNavTheme.surfacePrimary.opacity(isDisabled ? 0.45 : 0.8))
                )
                .overlay(
                    Circle()
                        .stroke(CapsNavTheme.borderSoft.opacity(0.7), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(title)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

private struct SettingsProfileNameSheetContext: Identifiable {
    enum Mode {
        case create
        case duplicate(profileID: String, sourceName: String)
        case rename(profileID: String)

        var title: String {
            switch self {
            case .create:
                return "新增配置方案"
            case .duplicate:
                return "复制配置方案"
            case .rename:
                return "修改方案名称"
            }
        }

        var badgeTitle: String {
            switch self {
            case .create:
                return "复制默认方案"
            case .duplicate:
                return "复制现有方案"
            case .rename:
                return "更新方案名称"
            }
        }

        var submitButtonTitle: String {
            switch self {
            case .create:
                return "创建方案"
            case .duplicate:
                return "创建副本"
            case .rename:
                return "保存名称"
            }
        }
    }

    let id = UUID()
    let mode: Mode
    let initialName: String
    let existingNames: [String]
}

private struct SettingsProfileNameSheet: View {
    let context: SettingsProfileNameSheetContext
    let onSubmit: (String) -> Bool

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFieldFocused: Bool
    @State private var nameDraft: String
    @State private var hasAttemptedSubmit = false

    init(
        context: SettingsProfileNameSheetContext,
        onSubmit: @escaping (String) -> Bool
    ) {
        self.context = context
        self.onSubmit = onSubmit
        _nameDraft = State(initialValue: context.initialName)
    }

    private var normalizedName: String {
        nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasDuplicatedName: Bool {
        context.existingNames.contains { existingName in
            existingName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(normalizedName) == .orderedSame
        }
    }

    private var canCreate: Bool {
        !normalizedName.isEmpty && !hasDuplicatedName
    }

    private var helperText: String {
        if normalizedName.isEmpty {
            switch context.mode {
            case .create:
                return hasAttemptedSubmit ? "请输入配置方案名称。" : "会复制默认方案的全部快捷键与说明，创建后可继续编辑。"
            case let .duplicate(_, sourceName):
                return hasAttemptedSubmit ? "请输入配置方案名称。" : "会复制“\(sourceName)”的全部快捷键与说明，创建后可继续编辑。"
            case .rename:
                return hasAttemptedSubmit ? "请输入配置方案名称。" : "只会修改方案名称，不会改动已有的快捷键映射。"
            }
        }

        if hasDuplicatedName {
            return "已存在同名配置方案，请换一个名称。"
        }

        switch context.mode {
        case .create:
            return "创建后会立即切换到新方案，默认方案本身不会被修改。"
        case let .duplicate(_, sourceName):
            return "创建后会立即切换到新副本，“\(sourceName)”本身不会被改动。"
        case .rename:
            return "保存后新的方案名称会立即显示在列表和悬浮提示里。"
        }
    }

    private var helperTone: SettingsValueRow.Tone {
        canCreate ? .accent : ((hasAttemptedSubmit || hasDuplicatedName) ? .warning : .neutral)
    }

    private var helperIconName: String {
        switch helperTone {
        case .warning:
            return "exclamationmark.triangle.fill"
        default:
            return "info.circle.fill"
        }
    }

    private var subtitleText: String {
        switch context.mode {
        case .create:
            return "新方案会复制默认方案的全部快捷键与说明，适合在保留默认手感的前提下做个人化调整。"
        case let .duplicate(_, sourceName):
            return "新副本会完整复制“\(sourceName)”当前的快捷键与说明，适合在现有方案基础上继续微调。"
        case .rename:
            return "修改后的名称会同步用于方案列表、当前激活状态和悬浮帮助框。"
        }
    }

    private var metaPillTexts: [String] {
        switch context.mode {
        case .create:
            return ["默认方案保持不变", "创建后自动切换"]
        case .duplicate:
            return ["原方案保持不变", "创建后自动切换"]
        case .rename:
            return ["不影响已有映射", "立即更新显示名称"]
        }
    }

    var body: some View {
        ZStack {
            SettingsBackgroundView()

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(CapsNavTheme.accentSoft)
                            .frame(width: 58, height: 58)

                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(CapsNavTheme.accentStrong)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.mode.title)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textPrimary)

                        Text(subtitleText)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Text(context.mode.badgeTitle)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.accentStrong)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(CapsNavTheme.accentSoft)
                        )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("方案名称")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textPrimary)

                    TextField("如：办公编辑方案", text: $nameDraft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(CapsNavTheme.surfaceSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    (hasAttemptedSubmit && !canCreate) || hasDuplicatedName
                                    ? CapsNavTheme.warning.opacity(0.65)
                                    : CapsNavTheme.borderSoft.opacity(0.9),
                                    lineWidth: 1
                                )
                        )
                        .focused($isNameFieldFocused)
                        .onSubmit {
                            submitCreate()
                        }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: helperIconName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(helperTone.foreground)
                            .padding(.top, 2)

                        Text(helperText)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(minHeight: 22, alignment: .topLeading)
                }

                HStack(spacing: 10) {
                    ForEach(metaPillTexts, id: \.self) { text in
                        SettingsProfileMetaPill(text: text, isSelected: false)
                    }
                }

                HStack(spacing: 10) {
                    Spacer(minLength: 0)

                    Button("取消") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Button(context.mode.submitButtonTitle) {
                        submitCreate()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CapsNavTheme.accentStrong)
                    .disabled(!canCreate)
                }
            }
            .padding(30)
            .frame(width: 560, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(CapsNavTheme.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(CapsNavTheme.borderSoft.opacity(0.9), lineWidth: 1)
            )
            .shadow(color: CapsNavTheme.cardShadow.opacity(0.9), radius: 20, x: 0, y: 12)
            .padding(24)
        }
        .frame(width: 640)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isNameFieldFocused = true
            }
        }
    }

    private func submitCreate() {
        hasAttemptedSubmit = true

        guard canCreate else {
            return
        }

        if onSubmit(normalizedName) {
            dismiss()
        }
    }
}

private struct SettingsProfileSelectionCard: View {
    let profile: Profile
    let isSelected: Bool
    let canRename: Bool
    let canDelete: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDuplicate: () -> Void
    let onRevealInFinder: () -> Void
    let onDelete: () -> Void

    @State private var isDeleteConfirming = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textPrimary)
                        .lineLimit(2)

                    Text(isSelected ? "当前正在使用这套配置" : "点击切换到这套配置")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(isSelected ? CapsNavTheme.accentStrong : CapsNavTheme.textSecondary)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Text("已激活")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.accentStrong)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(CapsNavTheme.surfacePrimary.opacity(0.8))
                        )
                }
            }

            HStack(spacing: 8) {
                SettingsProfileMetaPill(text: "\(profile.mappings.count) 个映射", isSelected: isSelected)

                if profile.id == Profile.default.id {
                    SettingsProfileMetaPill(text: "默认方案", isSelected: false)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isSelected ? CapsNavTheme.accentSoft : CapsNavTheme.surfaceSecondary.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    isSelected ? CapsNavTheme.accentStrong.opacity(0.7) : CapsNavTheme.borderSoft.opacity(0.82),
                    lineWidth: 1
                )
        )
        .shadow(
            color: (isSelected ? CapsNavTheme.accentStrong.opacity(0.12) : CapsNavTheme.cardShadow.opacity(0.65)),
            radius: isSelected ? 16 : 10,
            x: 0,
            y: isSelected ? 10 : 6
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button("切换到这个方案", systemImage: isSelected ? "checkmark.circle.fill" : "checkmark.circle") {
                onSelect()
            }

            Divider()

            Button("修改名称", systemImage: "pencil") {
                onRename()
            }
            .disabled(!canRename)

            Button("复制方案", systemImage: "doc.on.doc") {
                onDuplicate()
            }

            Button("定位配置文件", systemImage: "folder") {
                onRevealInFinder()
            }

            Button("删除方案", systemImage: "trash", role: .destructive) {
                isDeleteConfirming = true
            }
            .disabled(!canDelete)
        }
        .confirmationDialog(
            "删除配置方案",
            isPresented: $isDeleteConfirming,
            titleVisibility: .visible
        ) {
            Button("确认删除", role: .destructive) {
                onDelete()
            }

            Button("取消", role: .cancel) {}
        } message: {
            Text("确认删除“\(profile.name)”吗？如果它正处于激活状态，Caps Nav 会自动切换到剩余列表中的第一个方案。")
        }
    }
}

private struct SettingsProfileDropDelegate: DropDelegate {
    let targetProfileID: String
    @Binding var draggingProfileID: String?
    @Binding var draggingHoverTargetProfileID: String?
    let onReorder: (String, String) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingProfileID,
              draggingProfileID != targetProfileID,
              draggingHoverTargetProfileID != targetProfileID else {
            return
        }

        draggingHoverTargetProfileID = targetProfileID

        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            onReorder(draggingProfileID, targetProfileID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            draggingProfileID = nil
            draggingHoverTargetProfileID = nil
        }

        return draggingProfileID != nil
    }

    func dropExited(info: DropInfo) {}
}

private struct SettingsProfileMetaPill: View {
    let text: String
    let isSelected: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(isSelected ? CapsNavTheme.accentStrong : CapsNavTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? CapsNavTheme.surfacePrimary.opacity(0.76) : CapsNavTheme.surfacePrimary.opacity(0.52))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(CapsNavTheme.borderSoft.opacity(0.7), lineWidth: 1)
            )
    }
}

private struct SettingsProfileEditorHeaderRow: View {
    let keyColumnWidth: CGFloat
    let actionColumnWidth: CGFloat
    let effectColumnWidth: CGFloat
    let operationColumnWidth: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("快捷键")
                .frame(width: keyColumnWidth, alignment: .leading)

            Text("功能")
                .frame(width: actionColumnWidth, alignment: .leading)

            Text("功能效果")
                .frame(width: effectColumnWidth, alignment: .leading)

            Text("快捷键说明")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("操作")
                .frame(width: operationColumnWidth, alignment: .trailing)
        }
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .foregroundStyle(CapsNavTheme.textMuted)
        .padding(.horizontal, 8)
    }
}

private struct SettingsPersistedMappingEditorRow: View {
    let mapping: Mapping
    let unavailableKeys: Set<String>
    let keyColumnWidth: CGFloat
    let actionColumnWidth: CGFloat
    let effectColumnWidth: CGFloat
    let operationColumnWidth: CGFloat
    let isReadOnly: Bool
    let onPreviewHoverChanged: (String, Output?, Bool) -> Void
    let onSelectKey: (String) -> Void
    let onSelectBuiltinAction: (BuiltinAction) -> Void
    let onEditShortcut: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SettingsMappingKeyMenu(
                selectedKey: mapping.trigger.key,
                unavailableKeys: unavailableKeys,
                fixedWidth: keyColumnWidth,
                triggerText: mapping.trigger.prefixIndicatorDisplayText,
                isReadOnly: isReadOnly,
                onSelect: onSelectKey
            )

            SettingsMappingActionMenu(
                selectedOutput: mapping.output,
                selectedTitle: mapping.editorActionDisplayName,
                fixedWidth: actionColumnWidth,
                isReadOnly: isReadOnly,
                onSelectBuiltinAction: onSelectBuiltinAction,
                onEditShortcut: onEditShortcut
            )

            SettingsMappingEffectCell(
                previewID: "persisted:\(mapping.trigger.signature)",
                output: mapping.output,
                fixedWidth: effectColumnWidth,
                onHoverChanged: onPreviewHoverChanged
            )

            SettingsMappingDescriptionCell(
                descriptionText: mapping.displayDescription
            )

            if isReadOnly {
                SettingsReadOnlyOperationCell(operationColumnWidth: operationColumnWidth)
            } else {
                SettingsDeleteActionButton(
                    title: "删除快捷键",
                    operationColumnWidth: operationColumnWidth,
                    onConfirm: onDelete
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CapsNavTheme.surfaceSecondary.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(CapsNavTheme.borderSoft.opacity(0.75), lineWidth: 1)
        )
    }
}

private struct SettingsDraftMappingEditorRow: View {
    let draft: SettingsDraftMapping
    let unavailableKeys: Set<String>
    let keyColumnWidth: CGFloat
    let actionColumnWidth: CGFloat
    let effectColumnWidth: CGFloat
    let operationColumnWidth: CGFloat
    let onPreviewHoverChanged: (String, Output?, Bool) -> Void
    let onSelectKey: (String) -> Void
    let onSelectBuiltinAction: (BuiltinAction) -> Void
    let onEditShortcut: () -> Void
    let onSave: () -> Void
    let onDelete: () -> Void

    private var canSave: Bool {
        draft.normalizedKey != nil && draft.output != nil
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SettingsMappingKeyMenu(
                selectedKey: draft.normalizedKey,
                unavailableKeys: unavailableKeys,
                fixedWidth: keyColumnWidth,
                triggerText: draft.normalizedKey.map { "+\($0)" } ?? "选择按键",
                onSelect: onSelectKey
            )

            SettingsMappingActionMenu(
                selectedOutput: draft.output,
                selectedTitle: draft.output?.userFacingDescription ?? "选择功能",
                fixedWidth: actionColumnWidth,
                onSelectBuiltinAction: onSelectBuiltinAction,
                onEditShortcut: onEditShortcut
            )

            SettingsMappingEffectCell(
                previewID: "draft:\(draft.id.uuidString)",
                output: draft.output,
                fixedWidth: effectColumnWidth,
                onHoverChanged: onPreviewHoverChanged
            )

            SettingsMappingDescriptionCell(
                descriptionText: draft.output?.suggestedDescription ?? "先选择功能，说明会自动同步"
            )
            
            HStack {
                Spacer(minLength: 0)

                Button("保存") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .tint(CapsNavTheme.accentStrong)
                .disabled(!canSave)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            SettingsDeleteActionButton(
                title: "删除草稿",
                confirmationText: "确认后会移除这条未保存的快捷键。",
                operationColumnWidth: operationColumnWidth,
                buttonTitle: "删除",
                buttonSymbolName: "trash",
                onConfirm: onDelete
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CapsNavTheme.accentSoft.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(CapsNavTheme.accentStrong.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct SettingsMappingKeyMenu: View {
    let selectedKey: String?
    let unavailableKeys: Set<String>
    let fixedWidth: CGFloat
    let triggerText: String
    var isReadOnly = false
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            ForEach(SettingsTriggerKeySection.allCases) { section in
                Section(section.title) {
                    ForEach(section.keys, id: \.self) { key in
                        Button {
                            onSelect(key)
                        } label: {
                            if key == selectedKey {
                                Label(key.settingsDisplayTitle, systemImage: "checkmark")
                            } else {
                                Text(key.settingsDisplayTitle)
                            }
                        }
                        .disabled(unavailableKeys.contains(key))
                    }
                }
            }
        } label: {
            SettingsMenuPill(
                title: selectedKey == nil ? "未设置" : triggerText,
                symbolName: "keyboard",
                isEnabled: !isReadOnly
            )
        }
        .menuStyle(.borderlessButton)
        .frame(width: fixedWidth, alignment: .leading)
        .disabled(isReadOnly)
    }
}

private struct SettingsMappingActionMenu: View {
    let selectedOutput: Output?
    let selectedTitle: String
    let fixedWidth: CGFloat
    var isReadOnly = false
    let onSelectBuiltinAction: (BuiltinAction) -> Void
    let onEditShortcut: () -> Void

    private var selectedBuiltinAction: BuiltinAction? {
        guard case let .builtin(action)? = selectedOutput else {
            return nil
        }

        return action
    }

    private var isShortcutSelected: Bool {
        guard case .shortcut? = selectedOutput else {
            return false
        }

        return true
    }

    var body: some View {
        Menu {
            ForEach(SettingsActionSection.allCases) { section in
                Section(section.title) {
                    ForEach(section.actions, id: \.self) { action in
                        Button {
                            onSelectBuiltinAction(action)
                        } label: {
                            if action == selectedBuiltinAction {
                                Label(action.displayName, systemImage: "checkmark")
                            } else {
                                Text(action.displayName)
                            }
                        }
                        .disabled(action == selectedBuiltinAction)
                    }
                }
            }

            Section("自定义快捷键") {
                Button {
                    onEditShortcut()
                } label: {
                    if isShortcutSelected {
                        Label("修改自定义快捷键...", systemImage: "checkmark")
                    } else {
                        Label("设置自定义快捷键...", systemImage: "keyboard.badge.ellipsis")
                    }
                }
            }
        } label: {
            SettingsMenuPill(
                title: selectedTitle,
                symbolName: "command",
                isEnabled: !isReadOnly
            )
        }
        .menuStyle(.borderlessButton)
        .frame(width: fixedWidth, alignment: .leading)
        .disabled(isReadOnly)
    }
}

private struct SettingsShortcutSheetContext: Identifiable {
    enum Target {
        case draft(id: UUID)
        case persisted(triggerSignature: String)
        case appToggleShortcut
    }

    enum ContextKind {
        case mappingOutput(triggerText: String?)
        case appToggle
    }

    let id = UUID()
    let target: Target
    let contextKind: ContextKind
    let initialShortcut: Shortcut?

    var title: String {
        switch contextKind {
        case .mappingOutput:
            return initialShortcut == nil ? "设置自定义快捷键" : "修改自定义快捷键"
        case .appToggle:
            return initialShortcut == nil ? "设置全局开关快捷键" : "修改全局开关快捷键"
        }
    }

    var subtitle: String {
        switch contextKind {
        case let .mappingOutput(triggerText):
            if let triggerText {
                return "为 \(triggerText) 配置要发送的目标快捷键。保存后会立即同步到当前配置方案与悬浮提示。"
            }

            return "先配置要发送的目标快捷键，保存后再回到列表选择触发键也可以。"
        case .appToggle:
            return "这个快捷键会在任何前台应用中切换 Caps Nav 的启用或暂停状态。为了避免误触，至少包含一个修饰键。"
        }
    }

    var submitButtonTitle: String {
        switch contextKind {
        case .mappingOutput:
            return initialShortcut == nil ? "保存快捷键" : "更新快捷键"
        case .appToggle:
            return initialShortcut == nil ? "保存全局快捷键" : "更新全局快捷键"
        }
    }

    var triggerDisplayText: String {
        switch contextKind {
        case let .mappingOutput(triggerText):
            return triggerText ?? "稍后再选择"
        case .appToggle:
            return "运行总开关"
        }
    }

    var requiresModifierKey: Bool {
        switch contextKind {
        case .mappingOutput:
            return false
        case .appToggle:
            return true
        }
    }
}

private enum SettingsShortcutInputMode: String, CaseIterable, Identifiable {
    case record
    case pick

    var id: String { rawValue }

    var title: String {
        switch self {
        case .record:
            return "直接录入"
        case .pick:
            return "列表选择"
        }
    }

    var helperText: String {
        switch self {
        case .record:
            return "点击录入框后，直接按下目标快捷键"
        case .pick:
            return "手动选择主键和修饰键"
        }
    }

    var symbolName: String {
        switch self {
        case .record:
            return "keyboard"
        case .pick:
            return "square.grid.2x2"
        }
    }
}

private struct SettingsShortcutSheet: View {
    let context: SettingsShortcutSheetContext
    let onSubmit: (Shortcut) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedKey: String?
    @State private var selectedModifiers: Set<ModifierKey>
    @State private var inputMode: SettingsShortcutInputMode = .record
    @State private var isRecorderFocused = true
    @State private var recorderFeedbackText: String?

    private let modifierGrid = [
        GridItem(.adaptive(minimum: 132, maximum: 160), spacing: 10, alignment: .top)
    ]

    init(
        context: SettingsShortcutSheetContext,
        onSubmit: @escaping (Shortcut) -> Void
    ) {
        self.context = context
        self.onSubmit = onSubmit
        _selectedKey = State(initialValue: context.initialShortcut?.key)
        _selectedModifiers = State(initialValue: Set(context.initialShortcut?.modifiers ?? []))
    }

    private var currentShortcut: Shortcut? {
        guard let selectedKey else {
            return nil
        }

        return Shortcut(key: selectedKey, modifiers: Array(selectedModifiers).sorted())
    }

    private var validationResult: GlobalToggleShortcutValidationResult {
        context.requiresModifierKey
            ? GlobalToggleShortcutRules.validate(currentShortcut)
            : .valid
    }

    private var validationMessage: String? {
        switch validationResult {
        case .valid:
            return nil
        case .missingModifier:
            return "全局开关快捷键至少要包含一个修饰键。"
        }
    }

    private var helperText: String {
        if let validationMessage {
            return validationMessage
        }

        if let recorderFeedbackText {
            return recorderFeedbackText
        }

        if let currentShortcut {
            switch context.contextKind {
            case .mappingOutput:
                return "保存后，说明列会自动更新为“发送 \(currentShortcut.userFacingDescription)”，配置文件也会写成 shortcut 类型。"
            case .appToggle:
                return "保存后，在任何前台应用里按 \(currentShortcut.userFacingDescription) 都可以切换 Caps Nav 的启用状态。"
            }
        }

        if inputMode == .record {
            return context.requiresModifierKey
                ? "推荐直接录入：点击录入框后，直接按下你想用的快捷键。全局开关快捷键至少包含一个修饰键。"
                : "默认推荐直接录入：点击录入框后，直接按下你想发送的快捷键。遇到不方便录的情况，再切到“列表选择”。"
        }

        return context.requiresModifierKey
            ? "先选择一个主键，再至少叠加一个 Shift、Control、Option 或 Command。"
            : "先选择一个主键，再按需叠加 Shift、Control、Option、Command。"
    }

    private var shortcutBinding: Binding<Shortcut?> {
        Binding(
            get: { currentShortcut },
            set: { newShortcut in
                selectedKey = newShortcut?.key
                selectedModifiers = Set(newShortcut?.modifiers ?? [])
            }
        )
    }

    var body: some View {
        ZStack {
            SettingsBackgroundView()

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(CapsNavTheme.accentSoft)
                            .frame(width: 58, height: 58)

                        Image(systemName: "keyboard.badge.ellipsis")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(CapsNavTheme.accentStrong)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.title)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textPrimary)

                        Text(context.subtitle)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Text("快捷键输出")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.accentStrong)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(CapsNavTheme.accentSoft)
                        )
                }

                if case .mappingOutput = context.contextKind {
                    HStack(spacing: 10) {
                        SettingsValuePill(title: "前缀键", value: "Caps Lock", tone: .accent)
                        SettingsValuePill(title: "触发键", value: context.triggerDisplayText, tone: .neutral)
                    }
                } else {
                    HStack(spacing: 10) {
                        SettingsValuePill(title: "用途", value: context.triggerDisplayText, tone: .accent)
                        SettingsValuePill(title: "要求", value: "至少一个修饰键", tone: .neutral)
                    }
                }

                SettingsShortcutInputModeSelector(
                    selectedMode: inputMode,
                    onSelect: { mode in
                        inputMode = mode
                        recorderFeedbackText = nil
                        if mode == .record {
                            isRecorderFocused = true
                        }
                    }
                )

                VStack(alignment: .leading, spacing: 16) {
                    if inputMode == .record {
                        SettingsShortcutRecorderCard(
                            shortcut: shortcutBinding,
                            isFocused: $isRecorderFocused,
                            feedbackText: $recorderFeedbackText
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("主键")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(CapsNavTheme.textPrimary)

                            SettingsShortcutKeyMenu(
                                selectedKey: selectedKey,
                                onSelect: {
                                    selectedKey = $0
                                    recorderFeedbackText = nil
                                }
                            )
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("修饰键")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(CapsNavTheme.textPrimary)

                            LazyVGrid(columns: modifierGrid, alignment: .leading, spacing: 10) {
                                ForEach(ModifierKey.allCases, id: \.self) { modifier in
                                    SettingsShortcutModifierChip(
                                        title: modifier.displayName,
                                        isSelected: selectedModifiers.contains(modifier),
                                        action: {
                                            recorderFeedbackText = nil

                                            if selectedModifiers.contains(modifier) {
                                                selectedModifiers.remove(modifier)
                                            } else {
                                                selectedModifiers.insert(modifier)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(CapsNavTheme.surfaceSecondary.opacity(0.92))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(CapsNavTheme.borderSoft.opacity(0.82), lineWidth: 1)
                )

                SettingsShortcutPreviewCard(shortcut: currentShortcut)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CapsNavTheme.accentStrong)
                        .padding(.top, 1)

                    Text(helperText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Spacer(minLength: 0)

                    Button("取消") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Button(context.submitButtonTitle) {
                        guard let currentShortcut else {
                            return
                        }

                        onSubmit(currentShortcut)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CapsNavTheme.accentStrong)
                    .disabled(currentShortcut == nil || validationMessage != nil)
                }
            }
            .padding(30)
            .frame(width: 640, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(CapsNavTheme.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(CapsNavTheme.borderSoft.opacity(0.9), lineWidth: 1)
            )
            .shadow(color: CapsNavTheme.cardShadow.opacity(0.9), radius: 20, x: 0, y: 12)
            .padding(24)
        }
        .frame(width: 720)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            isRecorderFocused = true
        }
    }
}

private struct SettingsShortcutInputModeSelector: View {
    let selectedMode: SettingsShortcutInputMode
    let onSelect: (SettingsShortcutInputMode) -> Void

    private let grid = [
        GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 10, alignment: .top)
    ]

    var body: some View {
        LazyVGrid(columns: grid, alignment: .leading, spacing: 10) {
            ForEach(SettingsShortcutInputMode.allCases) { mode in
                Button {
                    onSelect(mode)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: mode.symbolName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(selectedMode == mode ? CapsNavTheme.accentStrong : CapsNavTheme.textSecondary)

                            Text(mode.title)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(selectedMode == mode ? CapsNavTheme.textPrimary : CapsNavTheme.textSecondary)

                            Spacer(minLength: 0)
                        }

                        Text(mode.helperText)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selectedMode == mode ? CapsNavTheme.accentSoft : CapsNavTheme.surfaceSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                selectedMode == mode ? CapsNavTheme.accentStrong.opacity(0.6) : CapsNavTheme.borderSoft.opacity(0.85),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SettingsShortcutRecorderCard: View {
    @Binding var shortcut: Shortcut?
    @Binding var isFocused: Bool
    @Binding var feedbackText: String?

    private var recordedText: String {
        shortcut?.userFacingDescription ?? "点击这里，然后直接按下目标快捷键"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("快捷键录入")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textPrimary)

            HStack(alignment: .center, spacing: 12) {
                ZStack(alignment: .leading) {
                    SettingsShortcutRecorderRepresentable(
                        shortcut: $shortcut,
                        isFocused: $isFocused,
                        feedbackText: $feedbackText
                    )
                    .frame(maxWidth: .infinity, minHeight: 56)

                    HStack(spacing: 10) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(isFocused ? CapsNavTheme.accentStrong : CapsNavTheme.textMuted)

                        Text(recordedText)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(shortcut == nil ? CapsNavTheme.textSecondary : CapsNavTheme.textPrimary)
                            .lineLimit(2)

                        Spacer(minLength: 0)

                        if isFocused {
                            Text("正在录入")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(CapsNavTheme.accentStrong)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(CapsNavTheme.accentSoft)
                                )
                        } else {
                            Text("点击后录入")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(CapsNavTheme.textMuted)
                        }
                    }
                    .padding(.horizontal, 14)
                    .allowsHitTesting(false)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(CapsNavTheme.surfacePrimary.opacity(0.92))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isFocused ? CapsNavTheme.accentStrong.opacity(0.6) : CapsNavTheme.borderSoft.opacity(0.82),
                            lineWidth: 1
                        )
                )

                if shortcut != nil {
                    Button("清空") {
                        shortcut = nil
                        feedbackText = nil
                        isFocused = true
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text("支持常用字母、数字、符号、方向键以及 Delete、Forward Delete、Return、Space、Tab、Escape。")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SettingsShortcutRecorderRepresentable: NSViewRepresentable {
    @Binding var shortcut: Shortcut?
    @Binding var isFocused: Bool
    @Binding var feedbackText: String?

    func makeNSView(context: Context) -> SettingsShortcutRecorderNSView {
        let view = SettingsShortcutRecorderNSView(frame: .zero)
        configure(view)
        return view
    }

    func updateNSView(_ nsView: SettingsShortcutRecorderNSView, context: Context) {
        configure(nsView)

        guard isFocused,
              nsView.window?.firstResponder !== nsView else {
            return
        }

        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    private func configure(_ view: SettingsShortcutRecorderNSView) {
        view.onShortcutCaptured = { capturedShortcut in
            DispatchQueue.main.async {
                shortcut = capturedShortcut
                feedbackText = nil
            }
        }
        view.onUnsupportedKey = {
            DispatchQueue.main.async {
                feedbackText = "这个按键暂不支持直接录入，你可以改用“列表选择”来设置。"
            }
        }
        view.onFocusChanged = { focused in
            DispatchQueue.main.async {
                isFocused = focused
            }
        }
    }
}

private final class SettingsShortcutRecorderNSView: NSView {
    var onShortcutCaptured: ((Shortcut) -> Void)?
    var onUnsupportedKey: (() -> Void)?
    var onFocusChanged: ((Bool) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            onFocusChanged?(true)
        }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted {
            onFocusChanged?(false)
        }
        return accepted
    }

    override func keyDown(with event: NSEvent) {
        guard let key = SettingsShortcutRecorderKeyMap.key(for: event) else {
            onUnsupportedKey?()
            return
        }

        onShortcutCaptured?(
            Shortcut(
                key: key,
                modifiers: event.modifierFlags.capsNavShortcutModifiers
            )
        )
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown else {
            return super.performKeyEquivalent(with: event)
        }

        keyDown(with: event)
        return true
    }
}

private enum SettingsShortcutRecorderKeyMap {
    private static let keyCodes: [UInt16: String] = [
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x", 8: "c", 9: "v",
        11: "b", 12: "q", 13: "w", 14: "e", 15: "r", 16: "y", 17: "t", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 37: "l", 38: "j",
        39: "'", 40: "k", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "n", 46: "m", 47: ".",
        48: "tab", 36: "return", 49: "space", 50: "`", 51: "delete", 53: "escape", 117: "forwardDelete",
        123: "left", 124: "right", 125: "down", 126: "up"
    ]

    static func key(for event: NSEvent) -> String? {
        keyCodes[event.keyCode]
    }
}

private extension NSEvent.ModifierFlags {
    var capsNavShortcutModifiers: [ModifierKey] {
        let normalizedFlags = intersection(.deviceIndependentFlagsMask)
        var modifiers: [ModifierKey] = []

        if normalizedFlags.contains(.shift) {
            modifiers.append(.shift)
        }
        if normalizedFlags.contains(.control) {
            modifiers.append(.control)
        }
        if normalizedFlags.contains(.option) {
            modifiers.append(.option)
        }
        if normalizedFlags.contains(.command) {
            modifiers.append(.command)
        }

        return modifiers
    }
}

private struct SettingsShortcutKeyMenu: View {
    let selectedKey: String?
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            ForEach(SettingsShortcutKeySection.allCases) { section in
                Section(section.title) {
                    ForEach(section.keys, id: \.self) { key in
                        Button {
                            onSelect(key)
                        } label: {
                            if key == selectedKey {
                                Label(key.capsNavDisplayKeyTitle, systemImage: "checkmark")
                            } else {
                                Text(key.capsNavDisplayKeyTitle)
                            }
                        }
                    }
                }
            }
        } label: {
            SettingsMenuPill(
                title: selectedKey?.capsNavDisplayKeyTitle ?? "选择主键",
                symbolName: "keyboard"
            )
        }
        .menuStyle(.borderlessButton)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsShortcutModifierChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? CapsNavTheme.accentStrong : CapsNavTheme.textMuted)

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? CapsNavTheme.textPrimary : CapsNavTheme.textSecondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? CapsNavTheme.accentSoft : CapsNavTheme.surfacePrimary.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? CapsNavTheme.accentStrong.opacity(0.55) : CapsNavTheme.borderSoft.opacity(0.8),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsShortcutPreviewCard: View {
    let shortcut: Shortcut?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("实时预览")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textPrimary)

            Text(shortcut?.userFacingDescription ?? "尚未设置目标快捷键")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(shortcut == nil ? CapsNavTheme.textMuted : CapsNavTheme.accentStrong)
                .fixedSize(horizontal: false, vertical: true)

            Text("保存后，这条映射会转发成上面的快捷键组合。")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textSecondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(CapsNavTheme.surfaceSecondary.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(CapsNavTheme.borderSoft.opacity(0.82), lineWidth: 1)
        )
    }
}

private extension PreferencesRootView {
    var operationalStateTone: SettingsValueRow.Tone {
        switch appBootstrap.operationalState {
        case .enabled:
            return .success
        case .paused:
            return .warning
        case .permissionRequired:
            return .accent
        }
    }
}

private struct SettingsMappingEffectCell: View {
    let previewID: String
    let output: Output?
    let fixedWidth: CGFloat
    let onHoverChanged: (String, Output?, Bool) -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            SettingsMappingEffectTrigger(
                previewID: previewID,
                output: output,
                onHoverChanged: onHoverChanged
            )
            Spacer(minLength: 0)
        }
        .frame(width: fixedWidth, alignment: .center)
    }
}

private struct SettingsMappingEffectTrigger: View {
    let previewID: String
    let output: Output?
    let onHoverChanged: (String, Output?, Bool) -> Void

    private var isPreviewAvailable: Bool {
        output != nil
    }

    private var symbolName: String {
        switch output {
        case .builtin:
            return "play.rectangle.on.rectangle.fill"
        case .shortcut:
            return "keyboard.badge.ellipsis"
        case nil:
            return "sparkles.slash"
        }
    }

    private var badgeTitle: String {
        switch output {
        case .builtin:
            return "预览"
        case .shortcut:
            return "说明"
        case nil:
            return "待选"
        }
    }

    private var helpText: String {
        switch output {
        case .builtin:
            return "鼠标悬停查看动态效果预览"
        case .shortcut:
            return "鼠标悬停查看自定义快捷键说明"
        case nil:
            return "先选择功能后再预览"
        }
    }

    private var iconColor: Color {
        switch output {
        case .builtin:
            return CapsNavTheme.accentStrong
        case .shortcut:
            return CapsNavTheme.textPrimary
        case nil:
            return CapsNavTheme.textMuted
        }
    }

    private var backgroundColor: Color {
        switch output {
        case .builtin:
            return CapsNavTheme.accentSoft
        case .shortcut:
            return CapsNavTheme.surfacePrimary
        case nil:
            return CapsNavTheme.surfaceSecondary
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(iconColor)

            Text(badgeTitle)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(output == nil ? CapsNavTheme.textMuted : CapsNavTheme.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    output == nil
                        ? CapsNavTheme.borderSoft.opacity(0.72)
                        : CapsNavTheme.accentStrong.opacity(0.18),
                    lineWidth: 1
                )
        )
        .opacity(output == nil ? 0.72 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .help(helpText)
        .background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: SettingsMappingEffectTriggerFramePreferenceKey.self,
                    value: isPreviewAvailable
                        ? [previewID: geometry.frame(in: .named(settingsMappingEffectPreviewCoordinateSpaceName))]
                        : [:]
                )
            }
        )
        .onHover { hovering in
            onHoverChanged(previewID, output, hovering)
        }
        .onDisappear {
            onHoverChanged(previewID, output, false)
        }
    }
}

private struct SettingsMappingEffectHoverCard: View {
    let output: Output

    var body: some View {
        Group {
            switch output {
            case let .builtin(action):
                SettingsBuiltinEffectHoverCard(action: action)
            case let .shortcut(shortcut):
                SettingsShortcutEffectHoverCard(shortcut: shortcut)
            }
        }
        .frame(width: 360, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(CapsNavTheme.surfacePrimarySolid)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(CapsNavTheme.borderSoft.opacity(0.92), lineWidth: 1)
        )
        .shadow(color: CapsNavTheme.cardShadow.opacity(0.95), radius: 18, x: 0, y: 12)
    }
}

private struct SettingsPreviewCardSizeReader: View {
    @Binding var size: CGSize

    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear {
                    updateSizeIfNeeded(geometry.size)
                }
                .onChange(of: geometry.size) { newSize in
                    updateSizeIfNeeded(newSize)
                }
        }
    }

    private func updateSizeIfNeeded(_ newSize: CGSize) {
        guard newSize != .zero, newSize != size else {
            return
        }

        DispatchQueue.main.async {
            size = newSize
        }
    }
}

private struct SettingsBuiltinEffectHoverCard: View {
    let action: BuiltinAction

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(CapsNavTheme.accentSoft)
                        .frame(width: 42, height: 42)

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(CapsNavTheme.accentStrong)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(action.displayName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textPrimary)

                    Text(action.defaultShortcutDescription)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            SettingsAnimatedBuiltinEffectPreview(action: action)

            Text("这里只做文本编辑效果演示，帮助建立“按键 -> 光标/选区/文本变化”的直觉。")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private enum SettingsEffectPreviewStage {
    case before
    case after
}

private struct SettingsAnimatedBuiltinEffectPreview: View {
    let action: BuiltinAction
    @State private var selectedStage: SettingsEffectPreviewStage = .before
    @State private var isAutoPlaying = true

    private let autoPlayTimer = Timer.publish(every: 2.6, on: .main, in: .common).autoconnect()

    private var previewPresentation: ShortcutTrainerPreviewPresentation {
        ShortcutTrainerPreviewFactory.make(for: .builtin(action: action))
    }

    private var isShowingAfterState: Bool {
        selectedStage == .after
    }

    var body: some View {
        switch previewPresentation {
        case let .editor(before, after):
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    SettingsEffectStageToggleButton(
                        title: "动作前",
                        isActive: selectedStage == .before,
                        action: {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                selectedStage = .before
                            }
                            isAutoPlaying = false
                        }
                    )

                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(CapsNavTheme.accentStrong)
                        .scaleEffect(isShowingAfterState ? 1.04 : 0.92)

                    SettingsEffectStageToggleButton(
                        title: "动作后",
                        isActive: selectedStage == .after,
                        action: {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                selectedStage = .after
                            }
                            isAutoPlaying = false
                        }
                    )

                    Spacer(minLength: 0)

                    SettingsEffectPlaybackButton(
                        isAutoPlaying: isAutoPlaying,
                        action: {
                            isAutoPlaying.toggle()
                        }
                    )
                }

                ZStack {
                    ShortcutTrainerEditorCanvas(snapshot: before)
                        .opacity(isShowingAfterState ? 0 : 1)
                        .offset(x: isShowingAfterState ? -12 : 0)
                        .scaleEffect(isShowingAfterState ? 0.992 : 1)

                    ShortcutTrainerEditorCanvas(snapshot: after)
                        .opacity(isShowingAfterState ? 1 : 0)
                        .offset(x: isShowingAfterState ? 0 : 12)
                        .scaleEffect(isShowingAfterState ? 1 : 0.992)
                }
                .frame(maxWidth: .infinity)
            }
            .onReceive(autoPlayTimer) { _ in
                guard isAutoPlaying else {
                    return
                }

                withAnimation(.easeInOut(duration: 0.55)) {
                    selectedStage = selectedStage == .before ? .after : .before
                }
            }
            .onDisappear {
                selectedStage = .before
                isAutoPlaying = true
            }

        case .shortcut:
            EmptyView()
        }
    }
}

private struct SettingsShortcutEffectHoverCard: View {
    let shortcut: Shortcut

    private let keycapGrid = [
        GridItem(.adaptive(minimum: 76, maximum: 110), spacing: 8, alignment: .top)
    ]

    private var shortcutTokens: [String] {
        shortcut.modifiers.map(\.displayName) + [shortcut.key.capsNavDisplayKeyTitle]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(CapsNavTheme.surfaceSecondary)
                        .frame(width: 42, height: 42)

                    Image(systemName: "keyboard.badge.ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(CapsNavTheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("自定义快捷键")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textPrimary)

                    Text("Caps Nav 会发送这组快捷键，但最终效果由当前应用决定。")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            LazyVGrid(columns: keycapGrid, alignment: .leading, spacing: 8) {
                ForEach(shortcutTokens, id: \.self) { token in
                    SettingsShortcutKeycap(title: token)
                }
            }

            Text(shortcut.userFacingDescription)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("适合用来确认“会发什么快捷键”，不适合在这里模拟真实文本结果。")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SettingsEffectStageToggleButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(isActive ? CapsNavTheme.textPrimary : CapsNavTheme.textMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(isActive ? CapsNavTheme.accentSoft : CapsNavTheme.surfaceSecondary)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            isActive ? CapsNavTheme.accentStrong.opacity(0.32) : CapsNavTheme.borderSoft.opacity(0.74),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsEffectPlaybackButton: View {
    let isAutoPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isAutoPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 10, weight: .bold))

                Text(isAutoPlaying ? "暂停自动播放" : "恢复自动播放")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isAutoPlaying ? CapsNavTheme.accentStrong : CapsNavTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(isAutoPlaying ? CapsNavTheme.accentSoft : CapsNavTheme.surfaceSecondary)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        isAutoPlaying ? CapsNavTheme.accentStrong.opacity(0.28) : CapsNavTheme.borderSoft.opacity(0.74),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsShortcutKeycap: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(CapsNavTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(CapsNavTheme.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(CapsNavTheme.borderSoft.opacity(0.8), lineWidth: 1)
            )
    }
}

private struct SettingsMappingDescriptionCell: View {
    let descriptionText: String

    var body: some View {
        Text(descriptionText)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(CapsNavTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsReadOnlyOperationCell: View {
    let operationColumnWidth: CGFloat

    var body: some View {
        Text("只读")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(CapsNavTheme.textMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(CapsNavTheme.surfacePrimary.opacity(0.9))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(CapsNavTheme.borderSoft.opacity(0.78), lineWidth: 1)
            )
            .frame(width: operationColumnWidth, alignment: .trailing)
    }
}

private struct SettingsDeleteActionButton: View {
    let title: String
    var confirmationText: String = "确认后会立即写回配置文件。"
    let operationColumnWidth: CGFloat
    var buttonTitle: String = "删除"
    var buttonSymbolName: String = "trash"
    let onConfirm: () -> Void

    @State private var isConfirming = false

    var body: some View {
        Button {
            isConfirming = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: buttonSymbolName)
                    .font(.system(size: 11, weight: .bold))

                Text(buttonTitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(CapsNavTheme.danger)
        }
        .buttonStyle(.borderless)
        .frame(width: operationColumnWidth, alignment: .trailing)
        .popover(isPresented: $isConfirming, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textPrimary)

                Text(confirmationText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textSecondary)

                HStack(spacing: 10) {
                    Button("取消") {
                        isConfirming = false
                    }
                    .buttonStyle(.bordered)

                    Button("确认删除") {
                        isConfirming = false
                        onConfirm()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CapsNavTheme.danger)
                }
            }
            .padding(16)
            .frame(width: 240, alignment: .leading)
        }
    }
}

private struct SettingsMenuPill: View {
    let title: String
    let symbolName: String
    var isEnabled = true

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbolName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isEnabled ? CapsNavTheme.accentStrong : CapsNavTheme.textMuted)

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(isEnabled ? CapsNavTheme.textPrimary : CapsNavTheme.textMuted)
                .lineLimit(1)

            Spacer(minLength: 0)

            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(CapsNavTheme.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(CapsNavTheme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(CapsNavTheme.borderSoft.opacity(0.85), lineWidth: 1)
        )
        .opacity(isEnabled ? 1 : 0.8)
    }
}

private struct SettingsMappingDescriptionRow: View {
    let triggerText: String
    let persistedDescription: String?
    let placeholderDescription: String
    let isEditing: Bool
    let draftText: String
    let onAddOrEdit: () -> Void
    let onDraftChange: (String) -> Void
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text(triggerText)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(CapsNavTheme.accentStrong)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(CapsNavTheme.accentSoft)
                    )
                    .frame(width: 128, alignment: .leading)

                if let persistedDescription {
                    Text(persistedDescription)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if !isEditing {
                    Button("添加说明") {
                        onAddOrEdit()
                    }
                    .buttonStyle(.bordered)
                    .tint(CapsNavTheme.accentStrong)
                } else {
                    Text("请输入快捷键说明")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textMuted)
                }

                Spacer(minLength: 0)

                if persistedDescription != nil {
                    Button {
                        onAddOrEdit()
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(CapsNavTheme.textMuted)
                }
            }

            if isEditing {
                VStack(alignment: .leading, spacing: 10) {
                    TextField(
                        placeholderDescription.isEmpty ? "填写快捷键说明" : placeholderDescription,
                        text: Binding(
                            get: { draftText },
                            set: { onDraftChange($0) }
                        )
                    )
                    .textFieldStyle(.roundedBorder)

                    HStack(spacing: 10) {
                        Button("保存") {
                            onSave()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(CapsNavTheme.accentStrong)

                        Button("取消") {
                            onCancel()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CapsNavTheme.surfaceSecondary.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(CapsNavTheme.borderSoft.opacity(0.75), lineWidth: 1)
        )
    }
}

private struct SettingsMappingPreviewRow: View {
    let triggerText: String
    let descriptionText: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(triggerText)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(CapsNavTheme.accentStrong)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(CapsNavTheme.accentSoft)
                )
                .frame(width: 128, alignment: .leading)

            Text(descriptionText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CapsNavTheme.surfaceSecondary.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(CapsNavTheme.borderSoft.opacity(0.75), lineWidth: 1)
        )
    }
}

private struct SettingsPathRow: View {
    let title: String
    let path: String
    let buttonTitle: String
    let buttonSymbolName: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textPrimary)

            HStack(alignment: .center, spacing: 12) {
                Text(path)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(CapsNavTheme.textSecondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    action()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: buttonSymbolName)
                            .font(.system(size: 12, weight: .bold))

                        Text(buttonTitle)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(CapsNavTheme.accentStrong)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        Capsule(style: .continuous)
                            .fill(CapsNavTheme.accentSoft)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(CapsNavTheme.accentStrong.opacity(0.22), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(CapsNavTheme.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(CapsNavTheme.borderSoft.opacity(0.8), lineWidth: 1)
            )
        }
    }
}

private struct SettingsWindowConfigurator: NSViewRepresentable {
    let minSize: NSSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configureWindowIfNeeded(for: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureWindowIfNeeded(for: nsView)
        }
    }

    private func configureWindowIfNeeded(for view: NSView) {
        guard let window = view.window else {
            return
        }

        if !window.styleMask.contains(.resizable) {
            window.styleMask.insert(.resizable)
        }

        if window.minSize != minSize {
            window.minSize = minSize
        }
    }
}

private struct SettingsEmptyState: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(CapsNavTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(CapsNavTheme.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(CapsNavTheme.borderSoft.opacity(0.75), lineWidth: 1)
            )
    }
}

private struct SettingsDraftMapping: Identifiable, Equatable {
    let id = UUID()
    var key = ""
    var output: Output?

    var normalizedKey: String? {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }
}

private enum SettingsTriggerKeySection: String, CaseIterable, Identifiable {
    case letters
    case numbers
    case symbols

    var id: String { rawValue }

    var title: String {
        switch self {
        case .letters:
            return "字母"
        case .numbers:
            return "数字"
        case .symbols:
            return "常用符号"
        }
    }

    var keys: [String] {
        switch self {
        case .letters:
            return Array("abcdefghijklmnopqrstuvwxyz").map(String.init)
        case .numbers:
            return Array("1234567890").map(String.init)
        case .symbols:
            return [";", "'", ",", ".", "/", "[", "]", "-", "="]
        }
    }
}

private enum SettingsActionSection: String, CaseIterable, Identifiable {
    case movement
    case selection
    case deletion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .movement:
            return "移动"
        case .selection:
            return "选中"
        case .deletion:
            return "删除"
        }
    }

    var actions: [BuiltinAction] {
        switch self {
        case .movement:
            return [
                .moveLeft,
                .moveRight,
                .moveUp,
                .moveDown,
                .moveWordLeft,
                .moveWordRight,
                .moveToLineStart,
                .moveToLineEnd
            ]
        case .selection:
            return [
                .selectLeft,
                .selectRight,
                .selectUp,
                .selectDown,
                .selectWordLeft,
                .selectWordRight,
                .selectToLineStart,
                .selectToLineEnd
            ]
        case .deletion:
            return [
                .deleteBackward,
                .deleteForward,
                .deleteWordBackward,
                .deleteWordForward
            ]
        }
    }
}

private enum SettingsShortcutKeySection: String, CaseIterable, Identifiable {
    case letters
    case numbers
    case symbols
    case arrows
    case common
    case editing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .letters:
            return "字母"
        case .numbers:
            return "数字"
        case .symbols:
            return "符号"
        case .arrows:
            return "方向键"
        case .common:
            return "常用按键"
        case .editing:
            return "编辑按键"
        }
    }

    var keys: [String] {
        switch self {
        case .letters:
            return Array("abcdefghijklmnopqrstuvwxyz").map(String.init)
        case .numbers:
            return Array("1234567890").map(String.init)
        case .symbols:
            return [";", "'", ",", ".", "/", "[", "]", "-", "=", "\\", "`"]
        case .arrows:
            return ["left", "right", "up", "down"]
        case .common:
            return ["return", "space", "tab", "escape"]
        case .editing:
            return ["delete", "forwardDelete"]
        }
    }
}

private extension String {
    var settingsDisplayTitle: String {
        capsNavDisplayKeyTitle
    }
}

private extension Mapping {
    var editorActionDisplayName: String {
        output.userFacingDescription
    }
}

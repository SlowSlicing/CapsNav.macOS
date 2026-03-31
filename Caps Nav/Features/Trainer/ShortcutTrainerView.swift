import AppKit
import Combine
import SwiftUI

struct ShortcutTrainerView: View {
    @ObservedObject var appBootstrap: AppBootstrap
    let onClose: () -> Void

    @StateObject private var session = ShortcutTrainerSession()
    private let leftPanelWidth: CGFloat = 328

    private let keyGrid = [
        GridItem(.adaptive(minimum: 210, maximum: 260), spacing: 12, alignment: .top)
    ]

    private var previewItem: ShortcutTrainerPracticeItem? {
        session.currentPrompt?.item ?? session.availableMappings.first
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [CapsNavTheme.windowTop, CapsNavTheme.windowBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(CapsNavTheme.glowPrimary)
                    .frame(width: 380, height: 380)
                    .blur(radius: 100)
                    .offset(x: -320, y: -250)

                Circle()
                    .fill(CapsNavTheme.glowSecondary)
                    .frame(width: 320, height: 320)
                    .blur(radius: 108)
                    .offset(x: 320, y: -240)

                ScrollView(.vertical) {
                    HStack(alignment: .top, spacing: 20) {
                        leftPanel
                            .frame(width: leftPanelWidth, alignment: .topLeading)

                        rightPanel
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .padding(26)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: max(geometry.size.height - 52, 0),
                        alignment: .topLeading
                    )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)

                ShortcutTrainerInputMonitorRepresentable(
                    isEnabled: session.phase == .running,
                    useLocalPrefixFallback: appBootstrap.accessibilityStatus != .trusted,
                    isPrefixContextActive: session.isPrefixVisualActive,
                    onLocalPrefixTriggered: {
                        session.armLocalPrefix()
                    },
                    onTriggerCaptured: { trigger in
                        session.handleLocalTrigger(trigger)
                    },
                    onUnsupportedKey: {
                        session.handleUnsupportedKey()
                    }
                )
                .allowsHitTesting(false)
                .frame(width: 1, height: 1)
                .opacity(0.001)
            }
        }
        .onAppear {
            session.updateProfile(appBootstrap.activeProfile)
            session.updateExternalPrefixPressed(appBootstrap.isPrefixActive)
        }
        .onChange(of: appBootstrap.activeProfileID) { _ in
            session.updateProfile(appBootstrap.activeProfile)
        }
        .onChange(of: appBootstrap.isPrefixActive) { isActive in
            session.updateExternalPrefixPressed(isActive)
        }
        .onChange(of: appBootstrap.highlightedPrefixTriggerSignature) { signature in
            guard let signature else {
                return
            }

            session.handleResolvedTriggerSignature(signature)
        }
    }

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(CapsNavTheme.accentSoft)
                        .frame(width: 94, height: 94)

                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(CapsNavTheme.accentStrong)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("快捷键练习")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textPrimary)

                    Text("用当前激活配置方案出题，快速建立 Caps Lock 前缀键的肌肉记忆。")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    ShortcutTrainerTag(title: session.profileName)
                    ShortcutTrainerTag(title: session.phase.displayName)
                }
            }

            ShortcutTrainerPrimaryActionCard(
                primaryTitle: session.primaryButtonTitle,
                secondaryTitle: session.phase == .finished ? "再来一轮" : nil,
                helperText: session.primaryActionHelperText,
                isPrimaryDisabled: session.availableMappings.isEmpty,
                onPrimary: {
                    session.startOrRestart()
                },
                onSecondary: {
                    session.restartCurrentMode()
                }
            )

            ShortcutTrainerPanelCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("训练模式")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textPrimary)

                    ForEach(ShortcutTrainerMode.allCases) { mode in
                        Button {
                            session.selectMode(mode)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 10) {
                                    Image(systemName: mode.symbolName)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(session.mode == mode ? CapsNavTheme.accentStrong : CapsNavTheme.textSecondary)

                                    Text(mode.displayName)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(CapsNavTheme.textPrimary)

                                    Spacer(minLength: 0)

                                    Text("\(mode.questionCount) 题")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(session.mode == mode ? CapsNavTheme.accentStrong : CapsNavTheme.textMuted)
                                }

                                Text(mode.helperText)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(CapsNavTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(session.mode == mode ? CapsNavTheme.accentSoft : CapsNavTheme.surfaceSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(
                                        session.mode == mode ? CapsNavTheme.accentStrong.opacity(0.55) : CapsNavTheme.borderSoft.opacity(0.82),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(session.phase == .running)
                    }
                }
            }

            ShortcutTrainerPanelCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("本轮状态")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textPrimary)

                    HStack(spacing: 10) {
                        ShortcutTrainerMetricPill(title: "进度", value: session.progressText, tone: .accent)
                        ShortcutTrainerMetricPill(title: "连击", value: "\(session.streak)", tone: .success)
                    }

                    HStack(spacing: 10) {
                        ShortcutTrainerMetricPill(title: "正确率", value: session.accuracyText, tone: .accent)
                        ShortcutTrainerMetricPill(title: "平均反应", value: session.averageResponseTimeText, tone: .neutral)
                    }
                }
            }

            ShortcutTrainerPanelCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("练习规则")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textPrimary)

                    ShortcutTrainerRuleRow(text: "训练会优先读取当前激活配置方案中的快捷键映射。")
                    ShortcutTrainerRuleRow(text: "已授予辅助功能权限时，会尽量按真实 Caps Lock 手感来识别。")
                    ShortcutTrainerRuleRow(text: "未授予辅助功能权限时，训练窗口会用“按一次 Caps 再答题”的方式做本地模拟。")
                    ShortcutTrainerRuleRow(text: "连招挑战更偏节奏训练；认键练习更适合第一次熟悉键位。")
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button("关闭窗口") {
                    onClose()
                }
                .buttonStyle(.bordered)

                if session.phase == .running {
                    Text("训练进行中：按住 Caps Lock，再按题目对应的答案键。")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(22)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(CapsNavTheme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(CapsNavTheme.borderSoft.opacity(0.88), lineWidth: 1)
        )
        .shadow(color: CapsNavTheme.cardShadow.opacity(0.92), radius: 24, x: 0, y: 14)
    }

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerBar

            promptCard

            ShortcutTrainerActionPreviewCard(item: previewItem)

            ShortcutTrainerFeedbackBanner(feedback: session.feedback)

            HStack(alignment: .top, spacing: 16) {
                ShortcutTrainerPanelCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("当前方案键位概览")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(CapsNavTheme.textPrimary)

                            Spacer(minLength: 0)

                            Text("\(session.availableMappings.count) 条映射")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(CapsNavTheme.textMuted)
                        }

                        if session.availableMappings.isEmpty {
                            Text("当前方案里还没有可练习的按键映射。")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(CapsNavTheme.textSecondary)
                        } else {
                            LazyVGrid(columns: keyGrid, alignment: .leading, spacing: 12) {
                                ForEach(session.availableMappings) { item in
                                    ShortcutTrainerKeyChip(
                                        item: item,
                                        isCurrentPrompt: session.currentPrompt?.item.id == item.id,
                                        isHighlighted: session.highlightedTriggerSignature == item.triggerSignature
                                    )
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                ShortcutTrainerPanelCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("本轮总结")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textPrimary)

                        ShortcutTrainerSummaryRow(title: "答对", value: "\(session.correctCount)")
                        ShortcutTrainerSummaryRow(title: "答错", value: "\(session.wrongCount)")
                        ShortcutTrainerSummaryRow(title: "最佳连击", value: "\(session.bestStreak)")
                        ShortcutTrainerSummaryRow(title: "平均反应", value: session.averageResponseTimeText)

                        Divider()

                        if session.mostMissedItems.isEmpty {
                            Text("本轮还没有错误记录，继续保持。")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(CapsNavTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("易错项")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(CapsNavTheme.textPrimary)

                            ForEach(session.mostMissedItems, id: \.item.id) { entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.item.promptText)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(CapsNavTheme.textPrimary)

                                    Text("正确答案：\(entry.item.expectedAnswerText) · 错误 \(entry.count) 次")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(CapsNavTheme.textSecondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
                .frame(width: 250, alignment: .topLeading)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("当前方案：\(session.profileName)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textPrimary)

                Text(session.prefixStatusText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(session.isPrefixVisualActive ? CapsNavTheme.success : CapsNavTheme.textSecondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                ShortcutTrainerMetricPill(title: "模式", value: session.mode.displayName, tone: .neutral)
                ShortcutTrainerMetricPill(title: "剩余", value: session.remainingText, tone: .neutral)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(CapsNavTheme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(CapsNavTheme.borderSoft.opacity(0.88), lineWidth: 1)
        )
        .shadow(color: CapsNavTheme.cardShadow.opacity(0.72), radius: 16, x: 0, y: 8)
    }

    private var promptCard: some View {
        ShortcutTrainerPanelCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(session.phaseHeadline)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textMuted)

                Text(session.promptTitleText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(session.promptSubtitleText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    ShortcutTrainerPromptBadge(
                        title: "目标答案",
                        value: session.currentPrompt?.item.expectedAnswerText ?? "开始后显示"
                    )
                    ShortcutTrainerPromptBadge(
                        title: "输出效果",
                        value: session.currentPrompt?.item.outputText ?? "根据题目自动更新"
                    )
                }
            }
        }
    }
}

@MainActor
private final class ShortcutTrainerSession: ObservableObject {
    @Published var mode: ShortcutTrainerMode = .recognition
    @Published private(set) var phase: ShortcutTrainerPhase = .idle
    @Published private(set) var profileName = "暂无配置方案"
    @Published private(set) var availableMappings: [ShortcutTrainerPracticeItem] = []
    @Published private(set) var currentPrompt: ShortcutTrainerPrompt?
    @Published private(set) var feedback: ShortcutTrainerFeedback = .instruction(
        title: "准备开始",
        detail: "点击上方醒目的主按钮开始训练，或先切换到你想练习的配置方案。"
    )
    @Published private(set) var correctCount = 0
    @Published private(set) var wrongCount = 0
    @Published private(set) var streak = 0
    @Published private(set) var bestStreak = 0
    @Published private(set) var highlightedTriggerSignature: String?
    @Published private(set) var isPrefixVisualActive = false

    private var profileItemsBySignature: [String: ShortcutTrainerPracticeItem] = [:]
    private var queuedItems: [ShortcutTrainerPracticeItem] = []
    private var currentPromptStartedAt: Date?
    private var responseSamples: [TimeInterval] = []
    private var mistakeCounts: [String: Int] = [:]
    private var isAcceptingInput = false
    private var externalPrefixPressed = false
    private var localPrefixArmed = false
    private var localPrefixClearWorkItem: DispatchWorkItem?
    private var advanceWorkItem: DispatchWorkItem?
    private var highlightClearWorkItem: DispatchWorkItem?
    private(set) var completedCount = 0
    private(set) var totalCount = 0

    func updateProfile(_ profile: Profile?) {
        cancelScheduledWork()

        let items = (profile?.mappings ?? [])
            .map(ShortcutTrainerPracticeItem.init(mapping:))
            .sorted(by: ShortcutTrainerPracticeItem.sortComparator)

        availableMappings = items
        profileItemsBySignature = Dictionary(uniqueKeysWithValues: items.map { ($0.triggerSignature, $0) })
        profileName = profile?.name ?? "暂无配置方案"

        guard phase == .running else {
            resetPresentation(
                feedback: .instruction(
                    title: "准备开始",
                    detail: items.isEmpty
                        ? "当前激活方案里还没有可练习的映射。先去“配置方案”里补充一些键位。"
                        : "点击上方主按钮开始训练，题目会直接从当前激活配置方案里生成。"
                )
            )
            return
        }

        resetPresentation(
            feedback: .warning(
                title: "训练已重置",
                detail: "当前激活配置方案发生了变化，请重新开始一轮训练。"
            )
        )
    }

    func selectMode(_ mode: ShortcutTrainerMode) {
        guard phase != .running else {
            return
        }

        self.mode = mode
        if phase == .finished {
            feedback = .instruction(
                title: "模式已切换",
                detail: "点击上方主按钮即可按新的模式重新开始。"
            )
        }
    }

    func startOrRestart() {
        guard !availableMappings.isEmpty else {
            feedback = .warning(
                title: "暂无题目",
                detail: "当前配置方案里没有可练习的映射，先去“配置方案”添加一些快捷键。"
            )
            return
        }

        restartCurrentMode()
    }

    func restartCurrentMode() {
        cancelScheduledWork()
        localPrefixArmed = false
        externalPrefixPressed = false
        isPrefixVisualActive = false
        highlightedTriggerSignature = nil

        queuedItems = Self.buildQueue(from: availableMappings, count: mode.questionCount)
        totalCount = queuedItems.count
        completedCount = 0
        correctCount = 0
        wrongCount = 0
        streak = 0
        bestStreak = 0
        responseSamples = []
        mistakeCounts = [:]
        phase = .running
        presentNextPrompt()
    }

    func updateExternalPrefixPressed(_ isPressed: Bool) {
        externalPrefixPressed = isPressed
        refreshEffectivePrefixState()

        if isPressed, phase == .running, isAcceptingInput {
            feedback = .instruction(
                title: "前缀已按下",
                detail: "继续输入题目对应的答案键。"
            )
        }
    }

    func armLocalPrefix() {
        guard phase == .running else {
            return
        }

        localPrefixClearWorkItem?.cancel()
        localPrefixArmed = true
        refreshEffectivePrefixState()
        feedback = .instruction(
            title: "已检测到 Caps",
            detail: "继续输入题目对应的答案键。"
        )

        let workItem = DispatchWorkItem { [weak self] in
            self?.localPrefixArmed = false
            self?.refreshEffectivePrefixState()
        }
        localPrefixClearWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: workItem)
    }

    func handleResolvedTriggerSignature(_ signature: String) {
        guard let item = profileItemsBySignature[signature] else {
            return
        }

        handleAnswer(
            using: item,
            matchedByProfile: true
        )
    }

    func handleLocalTrigger(_ trigger: Trigger) {
        guard phase == .running else {
            return
        }

        let attemptedItem = profileItemsBySignature[trigger.signature]
            ?? ShortcutTrainerPracticeItem(mapping: Mapping(trigger: trigger, output: .builtin(action: .moveLeft)))

        if let matchedItem = profileItemsBySignature[trigger.signature] {
            handleAnswer(using: matchedItem, matchedByProfile: true)
        } else {
            handleAnswer(using: attemptedItem, matchedByProfile: false)
        }
    }

    func handleUnsupportedKey() {
        guard phase == .running else {
            return
        }

        feedback = .warning(
            title: "这个按键暂不支持训练识别",
            detail: "当前版本优先练习常用字母、数字、方向键和常见编辑键。"
        )
    }

    var effectivePrefixActive: Bool {
        externalPrefixPressed || localPrefixArmed
    }

    var accuracyText: String {
        guard completedCount > 0 else {
            return "0%"
        }

        let accuracy = Double(correctCount) / Double(completedCount)
        return "\(Int((accuracy * 100).rounded()))%"
    }

    var averageResponseTimeText: String {
        guard !responseSamples.isEmpty else {
            return "--"
        }

        let average = responseSamples.reduce(0, +) / Double(responseSamples.count)
        return String(format: "%.2f 秒", average)
    }

    var progressText: String {
        "\(completedCount)/\(max(totalCount, 1))"
    }

    var remainingText: String {
        guard totalCount > 0 else {
            return "--"
        }

        return "\(max(totalCount - completedCount, 0))"
    }

    var phaseHeadline: String {
        switch phase {
        case .idle:
            return "准备开始"
        case .running:
            return currentPrompt.map { "第 \($0.index) / \($0.total) 题" } ?? "训练进行中"
        case .finished:
            return "本轮完成"
        }
    }

    var promptTitleText: String {
        switch phase {
        case .idle:
            return availableMappings.isEmpty ? "当前方案还没有可练习的快捷键" : "点击开始，按题目把答案敲出来"
        case .running:
            return currentPrompt?.item.promptText ?? "正在准备题目"
        case .finished:
            return "这一轮已经完成"
        }
    }

    var promptSubtitleText: String {
        switch phase {
        case .idle:
            return availableMappings.isEmpty
                ? "你可以先去“配置方案”补充映射，再回来训练。"
                : "训练时只需要专注一件事：先按住 Caps Lock，再按出题目对应的答案键。"
        case .running:
            return mode.runningSubtitle
        case .finished:
            return "正确 \(correctCount) 题，答错 \(wrongCount) 题，最佳连击 \(bestStreak)。你可以继续来一轮，或者切换模式再练。"
        }
    }

    var prefixStatusText: String {
        isPrefixVisualActive
            ? "前缀状态：已进入答题状态"
            : "前缀状态：等待 Caps Lock"
    }

    var primaryButtonTitle: String {
        switch phase {
        case .idle:
            return mode.startButtonTitle
        case .running:
            return "重新开始"
        case .finished:
            return mode.restartButtonTitle
        }
    }

    var primaryActionHelperText: String {
        if availableMappings.isEmpty {
            return "当前方案还没有可练习的映射，先去“配置方案”添加一些快捷键。"
        }

        switch phase {
        case .idle:
            return "建议先从\(mode.displayName)开始，按住 Caps Lock 后再按题目对应的答案键。"
        case .running:
            return "如果这一轮节奏乱了，可以直接重新开始，马上用当前模式重新出题。"
        case .finished:
            return "这一轮已经结束，你可以立刻再练一轮，继续巩固刚才的手感。"
        }
    }

    var mostMissedItems: [(item: ShortcutTrainerPracticeItem, count: Int)] {
        mistakeCounts
            .compactMap { signature, count -> (ShortcutTrainerPracticeItem, Int)? in
                guard let item = profileItemsBySignature[signature] else {
                    return nil
                }
                return (item, count)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.triggerSignature < rhs.0.triggerSignature
                }

                return lhs.1 > rhs.1
            }
            .prefix(3)
            .map { ($0.0, $0.1) }
    }

    private func handleAnswer(using attemptedItem: ShortcutTrainerPracticeItem, matchedByProfile: Bool) {
        guard phase == .running,
              isAcceptingInput,
              let currentPrompt else {
            return
        }

        let shouldConsumeLocalPrefix = localPrefixArmed
        if shouldConsumeLocalPrefix {
            localPrefixArmed = false
            localPrefixClearWorkItem?.cancel()
            refreshEffectivePrefixState()
        }

        guard effectivePrefixActive || shouldConsumeLocalPrefix else {
            feedback = .warning(
                title: "先按 Caps Lock",
                detail: "答题前要先进入前缀状态，再按题目对应的答案键。"
            )
            return
        }

        isAcceptingInput = false
        setHighlightedSignature(attemptedItem.triggerSignature)
        completedCount += 1

        let elapsed = max(Date().timeIntervalSince(currentPromptStartedAt ?? Date()), 0.01)

        if matchedByProfile && attemptedItem.triggerSignature == currentPrompt.item.triggerSignature {
            correctCount += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
            responseSamples.append(elapsed)

            feedback = .success(
                title: "答对了",
                detail: "\(attemptedItem.promptText) · \(attemptedItem.expectedAnswerText)"
            )
        } else {
            wrongCount += 1
            streak = 0
            mistakeCounts[currentPrompt.item.triggerSignature, default: 0] += 1

            let attemptedText = matchedByProfile
                ? attemptedItem.expectedAnswerText
                : "Caps + \(attemptedItem.triggerDisplayText)"

            feedback = .danger(
                title: "答错了",
                detail: "你按的是 \(attemptedText)，正确答案是 \(currentPrompt.item.expectedAnswerText)。"
            )
        }

        scheduleAdvance(after: mode.advanceDelay)
    }

    private func presentNextPrompt() {
        advanceWorkItem?.cancel()

        if queuedItems.isEmpty {
            phase = .finished
            currentPrompt = nil
            refreshEffectivePrefixState()
            feedback = .success(
                title: "训练完成",
                detail: "正确率 \(accuracyText)，平均反应 \(averageResponseTimeText)。如果想继续提速，可以切换到“连招挑战”。"
            )
            return
        }

        let nextItem = queuedItems.removeFirst()
        currentPrompt = ShortcutTrainerPrompt(
            item: nextItem,
            index: completedCount + 1,
            total: totalCount
        )
        currentPromptStartedAt = Date()
        isAcceptingInput = true
        feedback = .instruction(
            title: "开始答题",
            detail: "目标：\(nextItem.promptText)"
        )
    }

    private func scheduleAdvance(after delay: TimeInterval) {
        advanceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.presentNextPrompt()
        }
        advanceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func setHighlightedSignature(_ signature: String?) {
        highlightClearWorkItem?.cancel()
        highlightedTriggerSignature = signature

        guard signature != nil else {
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.highlightedTriggerSignature = nil
        }
        highlightClearWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    private func resetPresentation(feedback: ShortcutTrainerFeedback) {
        phase = .idle
        currentPrompt = nil
        currentPromptStartedAt = nil
        correctCount = 0
        wrongCount = 0
        streak = 0
        bestStreak = 0
        completedCount = 0
        totalCount = 0
        responseSamples = []
        mistakeCounts = [:]
        isAcceptingInput = false
        highlightedTriggerSignature = nil
        externalPrefixPressed = false
        localPrefixArmed = false
        isPrefixVisualActive = false
        self.feedback = feedback
    }

    private func cancelScheduledWork() {
        localPrefixClearWorkItem?.cancel()
        advanceWorkItem?.cancel()
        highlightClearWorkItem?.cancel()
    }

    private func refreshEffectivePrefixState() {
        isPrefixVisualActive = externalPrefixPressed || localPrefixArmed
    }

    private static func buildQueue(from items: [ShortcutTrainerPracticeItem], count: Int) -> [ShortcutTrainerPracticeItem] {
        guard !items.isEmpty else {
            return []
        }

        var queue: [ShortcutTrainerPracticeItem] = []

        while queue.count < count {
            queue.append(contentsOf: items.shuffled())
        }

        return Array(queue.prefix(count))
    }
}

private struct ShortcutTrainerPrompt: Equatable {
    let item: ShortcutTrainerPracticeItem
    let index: Int
    let total: Int
}

private struct ShortcutTrainerPracticeItem: Identifiable, Equatable {
    let id: String
    let triggerSignature: String
    let triggerDisplayText: String
    let expectedAnswerText: String
    let promptText: String
    let outputText: String
    let output: Output

    init(mapping: Mapping) {
        self.id = mapping.trigger.signature
        self.triggerSignature = mapping.trigger.signature
        let triggerText = (mapping.trigger.modifiers.map(\.displayName) + [mapping.trigger.key.capsNavDisplayKeyTitle])
            .joined(separator: " + ")
        self.triggerDisplayText = triggerText
        self.expectedAnswerText = "Caps + \(triggerText)"
        self.promptText = mapping.displayDescription
        self.outputText = mapping.output.userFacingDescription
        self.output = mapping.output
    }

    static let sortComparator: (ShortcutTrainerPracticeItem, ShortcutTrainerPracticeItem) -> Bool = { lhs, rhs in
        lhs.triggerSignature < rhs.triggerSignature
    }
}

private enum ShortcutTrainerMode: String, CaseIterable, Identifiable {
    case recognition
    case combo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .recognition:
            return "认键练习"
        case .combo:
            return "连招挑战"
        }
    }

    var symbolName: String {
        switch self {
        case .recognition:
            return "brain.head.profile"
        case .combo:
            return "bolt.fill"
        }
    }

    var helperText: String {
        switch self {
        case .recognition:
            return "节奏更稳，适合第一次熟悉动作和答案键。"
        case .combo:
            return "节奏更快，更适合已经知道键位后的提速训练。"
        }
    }

    var runningSubtitle: String {
        switch self {
        case .recognition:
            return "先看动作，再按出正确答案键。每题会给一点点反馈时间，方便你确认思路。"
        case .combo:
            return "按节奏快速答题，尽量把正确率和连击一起拉高。"
        }
    }

    var questionCount: Int {
        switch self {
        case .recognition:
            return 10
        case .combo:
            return 18
        }
    }

    var advanceDelay: TimeInterval {
        switch self {
        case .recognition:
            return 0.95
        case .combo:
            return 0.45
        }
    }

    var startButtonTitle: String {
        switch self {
        case .recognition:
            return "开始认键练习"
        case .combo:
            return "开始连招挑战"
        }
    }

    var restartButtonTitle: String {
        switch self {
        case .recognition:
            return "再来一轮认键练习"
        case .combo:
            return "再来一轮连招挑战"
        }
    }
}

private enum ShortcutTrainerPhase {
    case idle
    case running
    case finished

    var displayName: String {
        switch self {
        case .idle:
            return "未开始"
        case .running:
            return "训练中"
        case .finished:
            return "已完成"
        }
    }
}

private struct ShortcutTrainerFeedback: Equatable {
    let title: String
    let detail: String
    let tone: ShortcutTrainerFeedbackTone

    static func instruction(title: String, detail: String) -> ShortcutTrainerFeedback {
        ShortcutTrainerFeedback(title: title, detail: detail, tone: .accent)
    }

    static func success(title: String, detail: String) -> ShortcutTrainerFeedback {
        ShortcutTrainerFeedback(title: title, detail: detail, tone: .success)
    }

    static func warning(title: String, detail: String) -> ShortcutTrainerFeedback {
        ShortcutTrainerFeedback(title: title, detail: detail, tone: .warning)
    }

    static func danger(title: String, detail: String) -> ShortcutTrainerFeedback {
        ShortcutTrainerFeedback(title: title, detail: detail, tone: .danger)
    }
}

private enum ShortcutTrainerFeedbackTone: Equatable {
    case accent
    case success
    case warning
    case danger

    var color: Color {
        switch self {
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

    var backgroundColor: Color {
        switch self {
        case .accent:
            return CapsNavTheme.accentSoft
        case .success:
            return CapsNavTheme.accentSoft.opacity(0.72)
        case .warning:
            return CapsNavTheme.surfaceSecondary
        case .danger:
            return CapsNavTheme.surfaceSecondary
        }
    }
}

private struct ShortcutTrainerPanelCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(CapsNavTheme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(CapsNavTheme.borderSoft.opacity(0.82), lineWidth: 1)
        )
        .shadow(color: CapsNavTheme.cardShadow.opacity(0.7), radius: 14, x: 0, y: 8)
    }
}

private struct ShortcutTrainerPrimaryActionCard: View {
    let primaryTitle: String
    let secondaryTitle: String?
    let helperText: String
    let isPrimaryDisabled: Bool
    let onPrimary: () -> Void
    let onSecondary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(CapsNavTheme.surfacePrimarySolid.opacity(0.14))
                        .frame(width: 52, height: 52)

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.96))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("开始本轮练习")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)

                    Text(helperText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: onPrimary) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16, weight: .bold))

                    Text(primaryTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))

                    Spacer(minLength: 0)
                }
                .foregroundStyle(CapsNavTheme.accentStrong)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(CapsNavTheme.surfacePrimarySolid)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(CapsNavTheme.surfacePrimarySolid.opacity(0.68), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isPrimaryDisabled)
            .opacity(isPrimaryDisabled ? 0.62 : 1)

            if let secondaryTitle {
                Button(action: onSecondary) {
                    Text(secondaryTitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [CapsNavTheme.accentStrong, CapsNavTheme.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(CapsNavTheme.accentSoft.opacity(0.34), lineWidth: 1)
        )
        .shadow(color: CapsNavTheme.accentStrong.opacity(0.2), radius: 18, x: 0, y: 10)
    }
}

private struct ShortcutTrainerTag: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(CapsNavTheme.accentStrong)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(CapsNavTheme.accentSoft)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(CapsNavTheme.accentStrong.opacity(0.25), lineWidth: 1)
            )
    }
}

private struct ShortcutTrainerMetricPill: View {
    let title: String
    let value: String
    let tone: ShortcutTrainerMetricTone

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textMuted)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(tone.color)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tone.backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(CapsNavTheme.borderSoft.opacity(0.76), lineWidth: 1)
        )
    }
}

private enum ShortcutTrainerMetricTone {
    case accent
    case success
    case neutral

    var color: Color {
        switch self {
        case .accent:
            return CapsNavTheme.accentStrong
        case .success:
            return CapsNavTheme.success
        case .neutral:
            return CapsNavTheme.textPrimary
        }
    }

    var backgroundColor: Color {
        switch self {
        case .accent:
            return CapsNavTheme.accentSoft
        case .success:
            return CapsNavTheme.accentSoft.opacity(0.7)
        case .neutral:
            return CapsNavTheme.surfaceSecondary
        }
    }
}

private struct ShortcutTrainerRuleRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CapsNavTheme.accentStrong)
                .padding(.top, 2)

            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ShortcutTrainerPromptBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textMuted)

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(CapsNavTheme.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CapsNavTheme.borderSoft.opacity(0.82), lineWidth: 1)
        )
    }
}

private struct ShortcutTrainerFeedbackBanner: View {
    let feedback: ShortcutTrainerFeedback

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: feedback.tone == .success ? "checkmark.seal.fill" : "bolt.badge.clock.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(feedback.tone.color)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(feedback.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textPrimary)

                Text(feedback.detail)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(feedback.tone.backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(feedback.tone.color.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct ShortcutTrainerKeyChip: View {
    let item: ShortcutTrainerPracticeItem
    let isCurrentPrompt: Bool
    let isHighlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(item.expectedAnswerText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(isHighlighted ? CapsNavTheme.accentStrong : CapsNavTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isHighlighted ? CapsNavTheme.accentSoft : CapsNavTheme.surfacePrimary.opacity(0.88))
                    )

                Spacer(minLength: 0)
            }

            Text(item.promptText)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.outputText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    isCurrentPrompt
                    ? CapsNavTheme.accentSoft
                    : (isHighlighted ? CapsNavTheme.surfaceTertiary : CapsNavTheme.surfaceSecondary)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    isHighlighted
                    ? CapsNavTheme.accentStrong.opacity(0.65)
                    : (isCurrentPrompt ? CapsNavTheme.accentStrong.opacity(0.45) : CapsNavTheme.borderSoft.opacity(0.82)),
                    lineWidth: 1
                )
        )
    }
}

private struct ShortcutTrainerSummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textSecondary)

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textPrimary)
        }
    }
}

private struct ShortcutTrainerActionPreviewCard: View {
    let item: ShortcutTrainerPracticeItem?

    @State private var isPulseExpanded = false

    var body: some View {
        ShortcutTrainerPanelCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("文本效果沙盘")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textPrimary)

                        Text(subtitleText)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    if let item {
                        ShortcutTrainerTag(title: item.expectedAnswerText)
                    }
                }

                if let item {
                    switch item.previewPresentation {
                    case let .editor(before, after):
                        HStack(alignment: .center, spacing: 14) {
                            ShortcutTrainerEditorStatePanel(
                                title: "按下前",
                                snapshot: before
                            )

                            ShortcutTrainerPreviewTransitionBadge(
                                triggerText: item.expectedAnswerText,
                                isPulseExpanded: isPulseExpanded
                            )

                            ShortcutTrainerEditorStatePanel(
                                title: "按下后",
                                snapshot: after,
                                emphasis: .accent
                            )
                        }

                    case let .shortcut(shortcut):
                        ShortcutTrainerShortcutPreviewPanel(
                            triggerText: item.expectedAnswerText,
                            shortcut: shortcut,
                            isPulseExpanded: isPulseExpanded
                        )
                    }

                    Text(helperText(for: item))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("开始训练后，这里会把当前题目的文本效果直接演示出来。")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear {
            startPulseAnimation()
        }
        .onChange(of: item?.id) { _ in
            startPulseAnimation()
        }
    }

    private var subtitleText: String {
        if let item {
            switch item.previewPresentation {
            case .editor:
                return "把动作直接放进模拟编辑区里看一遍，用户会更容易建立“按键 -> 文本变化”的直觉。"
            case .shortcut:
                return "自定义快捷键更适合直接看到会发送哪组按键，实际效果由目标应用决定。"
            }
        }

        return "这里会优先展示当前题目对应的效果，不改动真实文本，只做训练演示。"
    }

    private func helperText(for item: ShortcutTrainerPracticeItem) -> String {
        switch item.previewPresentation {
        case .editor:
            return "这是文本编辑效果的模拟沙盘，不是底层键值说明。用户真正需要理解的是：按下这个组合后，光标、选区或文本会怎么变化。"
        case .shortcut:
            return "你当前配置的是自定义快捷键。Caps Nav 会发送这组按键，最终效果取决于当前应用是否为它绑定了文本动作。"
        }
    }

    private func startPulseAnimation() {
        isPulseExpanded = false

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isPulseExpanded = true
            }
        }
    }
}

private struct ShortcutTrainerEditorStatePanel: View {
    enum Emphasis {
        case neutral
        case accent

        var borderColor: Color {
            switch self {
            case .neutral:
                return CapsNavTheme.borderSoft.opacity(0.82)
            case .accent:
                return CapsNavTheme.accentStrong.opacity(0.42)
            }
        }

        var headerForeground: Color {
            switch self {
            case .neutral:
                return CapsNavTheme.textSecondary
            case .accent:
                return CapsNavTheme.accentStrong
            }
        }
    }

    let title: String
    let snapshot: ShortcutTrainerEditorSnapshot
    var emphasis: Emphasis = .neutral

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(emphasis.headerForeground)

            ShortcutTrainerEditorCanvas(snapshot: snapshot)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(CapsNavTheme.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(emphasis.borderColor, lineWidth: 1)
        )
    }
}

private struct ShortcutTrainerPreviewTransitionBadge: View {
    let triggerText: String
    let isPulseExpanded: Bool

    private let pulseDiameter: CGFloat = 54
    private let collapsedScale: CGFloat = 46.0 / 54.0

    var body: some View {
        VStack(spacing: 10) {
            Text("按下后")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textMuted)

            ZStack {
                Circle()
                    .fill(CapsNavTheme.accentSoft.opacity(isPulseExpanded ? 0.96 : 0.72))
                    .frame(width: pulseDiameter, height: pulseDiameter)
                    .scaleEffect(isPulseExpanded ? 1 : collapsedScale)

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(CapsNavTheme.accentStrong)
                    .scaleEffect(isPulseExpanded ? 1.08 : 0.94)
            }
            .frame(width: 60, height: 60)

            Text(triggerText)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 98)
    }
}

private struct ShortcutTrainerShortcutPreviewPanel: View {
    let triggerText: String
    let shortcut: Shortcut
    let isPulseExpanded: Bool

    private let keycapGrid = [
        GridItem(.adaptive(minimum: 86, maximum: 120), spacing: 8, alignment: .top)
    ]

    private var shortcutTokens: [String] {
        shortcut.modifiers.map(\.displayName) + [shortcut.key.capsNavDisplayKeyTitle]
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("触发方式")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textMuted)

                ShortcutTrainerTag(title: triggerText)
            }
            .frame(width: 140, alignment: .leading)

            ShortcutTrainerPreviewTransitionBadge(
                triggerText: "发送快捷键",
                isPulseExpanded: isPulseExpanded
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("会发送这组快捷键")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textMuted)

                LazyVGrid(columns: keycapGrid, alignment: .leading, spacing: 8) {
                    ForEach(shortcutTokens, id: \.self) { token in
                        ShortcutTrainerKeycapBadge(title: token)
                    }
                }

                Text("最终效果由当前应用对这组快捷键的定义决定。")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(CapsNavTheme.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(CapsNavTheme.borderSoft.opacity(0.82), lineWidth: 1)
        )
    }
}

private struct ShortcutTrainerKeycapBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(CapsNavTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(CapsNavTheme.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(CapsNavTheme.borderSoft.opacity(0.86), lineWidth: 1)
            )
    }
}

struct ShortcutTrainerEditorCanvas: View {
    let snapshot: ShortcutTrainerEditorSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Circle()
                    .fill(CapsNavTheme.danger)
                    .frame(width: 8, height: 8)

                Circle()
                    .fill(CapsNavTheme.warning)
                    .frame(width: 8, height: 8)

                Circle()
                    .fill(CapsNavTheme.success)
                    .frame(width: 8, height: 8)

                Spacer(minLength: 0)

                Text("模拟编辑区")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()
                .overlay(CapsNavTheme.borderSoft.opacity(0.75))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(snapshot.lines.enumerated()), id: \.offset) { lineIndex, lineText in
                    ShortcutTrainerEditorLineView(
                        lineText: lineText,
                        lineIndex: lineIndex,
                        marker: snapshot.marker
                    )
                }
            }
            .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CapsNavTheme.surfacePrimary.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(CapsNavTheme.borderSoft.opacity(0.82), lineWidth: 1)
        )
    }
}

private struct ShortcutTrainerEditorLineView: View {
    let lineText: String
    let lineIndex: Int
    let marker: ShortcutTrainerEditorMarker

    private var characters: [Character] {
        Array(lineText)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("\(lineIndex + 1)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textMuted)
                .frame(width: 22, alignment: .trailing)

            HStack(spacing: 0) {
                if characters.isEmpty {
                    if isCaret(at: 0) {
                        caretView
                    }

                    Text(" ")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.clear)
                } else {
                    ForEach(0..<characters.count, id: \.self) { characterIndex in
                        if isCaret(at: characterIndex) {
                            caretView
                        }

                        characterView(for: String(characters[characterIndex]), index: characterIndex)
                    }

                    if isCaret(at: characters.count) {
                        caretView
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
        }
    }

    private func characterView(for character: String, index: Int) -> some View {
        Text(verbatim: character)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(CapsNavTheme.textPrimary)
            .padding(.vertical, 1)
            .padding(.horizontal, 0.5)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isSelected(index: index) ? CapsNavTheme.accentSoft : .clear)
            )
    }

    private var caretView: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(CapsNavTheme.accentStrong)
            .frame(width: 2, height: 16)
            .padding(.horizontal, 0.5)
    }

    private func isCaret(at column: Int) -> Bool {
        guard case let .caret(location) = marker else {
            return false
        }

        return location.line == lineIndex && location.column == column
    }

    private func isSelected(index: Int) -> Bool {
        guard let range = selectedRange else {
            return false
        }

        return range.contains(index)
    }

    private var selectedRange: Range<Int>? {
        guard case let .selection(startLocation, endLocation) = marker else {
            return nil
        }

        let lowerBound = min(startLocation, endLocation)
        let upperBound = max(startLocation, endLocation)

        guard lineIndex >= lowerBound.line, lineIndex <= upperBound.line else {
            return nil
        }

        let lowerColumn = lineIndex == lowerBound.line ? lowerBound.column : 0
        let upperColumn = lineIndex == upperBound.line ? upperBound.column : characters.count
        let boundedLowerColumn = min(max(lowerColumn, 0), characters.count)
        let boundedUpperColumn = min(max(upperColumn, 0), characters.count)

        guard boundedLowerColumn < boundedUpperColumn else {
            return nil
        }

        return boundedLowerColumn..<boundedUpperColumn
    }
}

struct ShortcutTrainerEditorSnapshot: Equatable {
    let lines: [String]
    let marker: ShortcutTrainerEditorMarker
}

enum ShortcutTrainerEditorMarker: Equatable {
    case caret(ShortcutTrainerTextLocation)
    case selection(ShortcutTrainerTextLocation, ShortcutTrainerTextLocation)
}

struct ShortcutTrainerTextLocation: Equatable, Comparable {
    let line: Int
    let column: Int

    static func < (lhs: ShortcutTrainerTextLocation, rhs: ShortcutTrainerTextLocation) -> Bool {
        if lhs.line == rhs.line {
            return lhs.column < rhs.column
        }

        return lhs.line < rhs.line
    }
}

enum ShortcutTrainerPreviewPresentation: Equatable {
    case editor(before: ShortcutTrainerEditorSnapshot, after: ShortcutTrainerEditorSnapshot)
    case shortcut(Shortcut)
}

enum ShortcutTrainerPreviewFactory {
    private static let horizontalLine = "alpha beta gamma"
    private static let shortLine = "alpha beta"
    private static let codeLine = "let totalCount = items.count"
    private static let multiLine = [
        "let firstLine = value",
        "let secondLine = value",
        "let thirdLine = value"
    ]

    static func make(for output: Output) -> ShortcutTrainerPreviewPresentation {
        switch output {
        case let .builtin(action):
            return preview(for: action)
        case let .shortcut(shortcut):
            return .shortcut(shortcut)
        }
    }

    private static func preview(for action: BuiltinAction) -> ShortcutTrainerPreviewPresentation {
        switch action {
        case .moveLeft:
            return .editor(
                before: snapshot(lines: [horizontalLine], caretLine: 0, caretColumn: 11),
                after: snapshot(lines: [horizontalLine], caretLine: 0, caretColumn: 10)
            )
        case .moveRight:
            return .editor(
                before: snapshot(lines: [horizontalLine], caretLine: 0, caretColumn: 10),
                after: snapshot(lines: [horizontalLine], caretLine: 0, caretColumn: 11)
            )
        case .moveUp:
            return .editor(
                before: snapshot(lines: multiLine, caretLine: 1, caretColumn: 10),
                after: snapshot(lines: multiLine, caretLine: 0, caretColumn: 10)
            )
        case .moveDown:
            return .editor(
                before: snapshot(lines: multiLine, caretLine: 1, caretColumn: 10),
                after: snapshot(lines: multiLine, caretLine: 2, caretColumn: 10)
            )
        case .selectLeft:
            return .editor(
                before: snapshot(lines: [horizontalLine], caretLine: 0, caretColumn: 10),
                after: selectionSnapshot(lines: [horizontalLine], startLine: 0, startColumn: 9, endLine: 0, endColumn: 10)
            )
        case .selectRight:
            return .editor(
                before: snapshot(lines: [horizontalLine], caretLine: 0, caretColumn: 10),
                after: selectionSnapshot(lines: [horizontalLine], startLine: 0, startColumn: 10, endLine: 0, endColumn: 11)
            )
        case .selectUp:
            return .editor(
                before: snapshot(lines: multiLine, caretLine: 1, caretColumn: 10),
                after: selectionSnapshot(lines: multiLine, startLine: 0, startColumn: 10, endLine: 1, endColumn: 10)
            )
        case .selectDown:
            return .editor(
                before: snapshot(lines: multiLine, caretLine: 1, caretColumn: 10),
                after: selectionSnapshot(lines: multiLine, startLine: 1, startColumn: 10, endLine: 2, endColumn: 10)
            )
        case .moveWordLeft:
            return .editor(
                before: snapshot(lines: [horizontalLine], caretLine: 0, caretColumn: 11),
                after: snapshot(lines: [horizontalLine], caretLine: 0, caretColumn: 6)
            )
        case .moveWordRight:
            return .editor(
                before: snapshot(lines: [horizontalLine], caretLine: 0, caretColumn: 6),
                after: snapshot(lines: [horizontalLine], caretLine: 0, caretColumn: 11)
            )
        case .selectWordLeft:
            return .editor(
                before: snapshot(lines: [horizontalLine], caretLine: 0, caretColumn: 11),
                after: selectionSnapshot(lines: [horizontalLine], startLine: 0, startColumn: 6, endLine: 0, endColumn: 10)
            )
        case .selectWordRight:
            return .editor(
                before: snapshot(lines: [horizontalLine], caretLine: 0, caretColumn: 6),
                after: selectionSnapshot(lines: [horizontalLine], startLine: 0, startColumn: 6, endLine: 0, endColumn: 10)
            )
        case .moveToLineStart:
            return .editor(
                before: snapshot(lines: [codeLine], caretLine: 0, caretColumn: 15),
                after: snapshot(lines: [codeLine], caretLine: 0, caretColumn: 0)
            )
        case .moveToLineEnd:
            return .editor(
                before: snapshot(lines: [codeLine], caretLine: 0, caretColumn: 8),
                after: snapshot(lines: [codeLine], caretLine: 0, caretColumn: codeLine.count)
            )
        case .selectToLineStart:
            return .editor(
                before: snapshot(lines: [codeLine], caretLine: 0, caretColumn: 15),
                after: selectionSnapshot(lines: [codeLine], startLine: 0, startColumn: 0, endLine: 0, endColumn: 15)
            )
        case .selectToLineEnd:
            return .editor(
                before: snapshot(lines: [codeLine], caretLine: 0, caretColumn: 8),
                after: selectionSnapshot(lines: [codeLine], startLine: 0, startColumn: 8, endLine: 0, endColumn: codeLine.count)
            )
        case .deleteBackward:
            return .editor(
                before: snapshot(lines: [shortLine], caretLine: 0, caretColumn: shortLine.count),
                after: snapshot(lines: ["alpha bet"], caretLine: 0, caretColumn: "alpha bet".count)
            )
        case .deleteForward:
            return .editor(
                before: snapshot(lines: [shortLine], caretLine: 0, caretColumn: 6),
                after: snapshot(lines: ["alpha eta"], caretLine: 0, caretColumn: 6)
            )
        case .deleteWordBackward:
            return .editor(
                before: snapshot(lines: [horizontalLine], caretLine: 0, caretColumn: 11),
                after: snapshot(lines: ["alpha gamma"], caretLine: 0, caretColumn: 6)
            )
        case .deleteWordForward:
            return .editor(
                before: snapshot(lines: [horizontalLine], caretLine: 0, caretColumn: 6),
                after: snapshot(lines: ["alpha gamma"], caretLine: 0, caretColumn: 6)
            )
        }
    }

    private static func snapshot(
        lines: [String],
        caretLine: Int,
        caretColumn: Int
    ) -> ShortcutTrainerEditorSnapshot {
        ShortcutTrainerEditorSnapshot(
            lines: lines,
            marker: .caret(.init(line: caretLine, column: caretColumn))
        )
    }

    private static func selectionSnapshot(
        lines: [String],
        startLine: Int,
        startColumn: Int,
        endLine: Int,
        endColumn: Int
    ) -> ShortcutTrainerEditorSnapshot {
        ShortcutTrainerEditorSnapshot(
            lines: lines,
            marker: .selection(
                .init(line: startLine, column: startColumn),
                .init(line: endLine, column: endColumn)
            )
        )
    }
}

private extension ShortcutTrainerPracticeItem {
    var previewPresentation: ShortcutTrainerPreviewPresentation {
        ShortcutTrainerPreviewFactory.make(for: output)
    }
}

private struct ShortcutTrainerInputMonitorRepresentable: NSViewRepresentable {
    let isEnabled: Bool
    let useLocalPrefixFallback: Bool
    let isPrefixContextActive: Bool
    let onLocalPrefixTriggered: () -> Void
    let onTriggerCaptured: (Trigger) -> Void
    let onUnsupportedKey: () -> Void

    func makeNSView(context: Context) -> ShortcutTrainerInputMonitorView {
        let view = ShortcutTrainerInputMonitorView(frame: .zero)
        configure(view)
        return view
    }

    func updateNSView(_ nsView: ShortcutTrainerInputMonitorView, context: Context) {
        configure(nsView)
    }

    private func configure(_ view: ShortcutTrainerInputMonitorView) {
        view.isEnabled = isEnabled
        view.useLocalPrefixFallback = useLocalPrefixFallback
        view.isPrefixContextActive = isPrefixContextActive
        view.onLocalPrefixTriggered = onLocalPrefixTriggered
        view.onTriggerCaptured = onTriggerCaptured
        view.onUnsupportedKey = onUnsupportedKey
    }
}

private final class ShortcutTrainerInputMonitorView: NSView {
    var isEnabled = false
    var useLocalPrefixFallback = false
    var isPrefixContextActive = false
    var onLocalPrefixTriggered: (() -> Void)?
    var onTriggerCaptured: ((Trigger) -> Void)?
    var onUnsupportedKey: (() -> Void)?

    private var keyDownMonitor: Any?
    private var flagsChangedMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installMonitorsIfNeeded()
    }

    deinit {
        removeMonitors()
    }

    private func installMonitorsIfNeeded() {
        guard keyDownMonitor == nil, flagsChangedMonitor == nil else {
            return
        }

        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  self.isEnabled,
                  let window = self.window,
                  event.window === window else {
                return event
            }

            let normalizedFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if normalizedFlags.contains(.command) && !self.isPrefixContextActive {
                return event
            }

            guard let key = ShortcutTrainerKeyMap.key(for: event) else {
                self.onUnsupportedKey?()
                return nil
            }

            self.onTriggerCaptured?(
                Trigger(
                    key: key,
                    modifiers: normalizedFlags.shortcutTrainerModifiers
                )
            )
            return nil
        }

        flagsChangedMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self,
                  self.isEnabled,
                  self.useLocalPrefixFallback,
                  let window = self.window,
                  event.window === window else {
                return event
            }

            guard event.keyCode == 57 else {
                return event
            }

            self.onLocalPrefixTriggered?()
            return nil
        }
    }

    private func removeMonitors() {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
            self.keyDownMonitor = nil
        }

        if let flagsChangedMonitor {
            NSEvent.removeMonitor(flagsChangedMonitor)
            self.flagsChangedMonitor = nil
        }
    }
}

private enum ShortcutTrainerKeyMap {
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
    var shortcutTrainerModifiers: [ModifierKey] {
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

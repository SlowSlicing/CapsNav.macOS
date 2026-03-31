import Foundation

struct Profile: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    let version: Int
    var mappings: [Mapping]

    func validate() throws {
        if id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ProfileValidationError.emptyProfileIdentifier
        }

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ProfileValidationError.emptyProfileName
        }

        var signatures = Set<String>()

        for mapping in mappings {
            try mapping.validate()

            let signature = mapping.trigger.signature
            if !signatures.insert(signature).inserted {
                throw ProfileValidationError.duplicateTrigger(mapping.trigger.debugDescription)
            }
        }
    }
}

struct Mapping: Codable, Equatable {
    let trigger: Trigger
    let output: Output
    var description: String?

    static let unsetDescriptionDisplayText = "未设置快捷键说明"
    static let editorPlaceholderText = "如：光标向左移动一个字符"

    init(trigger: Trigger, output: Output, description: String? = nil) {
        self.trigger = trigger
        self.output = output
        self.description = description?.trimmedNilIfEmpty
    }

    func validate() throws {
        try trigger.validate()
    }

    var persistedDescription: String? {
        description?.trimmedNilIfEmpty
    }

    var displayDescription: String {
        persistedDescription ?? output.suggestedDescription ?? Self.unsetDescriptionDisplayText
    }

    var overlayDescription: String {
        displayDescription
    }

    var editorPlaceholderDescription: String {
        Self.editorPlaceholderText
    }

    var builtinAction: BuiltinAction? {
        guard case let .builtin(action) = output else {
            return nil
        }

        return action
    }

    var shortcut: Shortcut? {
        guard case let .shortcut(shortcut) = output else {
            return nil
        }

        return shortcut
    }
}

struct Trigger: Codable, Hashable, Equatable {
    let key: String
    let modifiers: [ModifierKey]

    init(key: String, modifiers: [ModifierKey]) {
        self.key = key
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        self.modifiers = Array(Set(modifiers)).sorted()
    }

    var signature: String {
        "\(key)|\(modifiers.map(\.rawValue).joined(separator: ","))"
    }

    var debugDescription: String {
        let modifierText = modifiers.map(\.displayName).joined(separator: " + ")

        if modifierText.isEmpty {
            return key
        }

        return "\(modifierText) + \(key)"
    }

    var prefixIndicatorDisplayText: String {
        let parts = modifiers.map(\.displayName) + [key]
        return "+\(parts.joined(separator: "+"))"
    }

    func validate() throws {
        if key.isEmpty {
            throw ProfileValidationError.emptyTriggerKey
        }
    }
}

enum ModifierKey: String, Codable, CaseIterable, Hashable, Comparable {
    case shift
    case control
    case option
    case command

    var displayName: String {
        switch self {
        case .shift:
            return "Shift"
        case .control:
            return "Control"
        case .option:
            return "Option"
        case .command:
            return "Command"
        }
    }

    private var sortIndex: Int {
        switch self {
        case .shift:
            return 0
        case .control:
            return 1
        case .option:
            return 2
        case .command:
            return 3
        }
    }

    static func < (lhs: ModifierKey, rhs: ModifierKey) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }
}

struct Shortcut: Codable, Equatable {
    let key: String
    let modifiers: [ModifierKey]

    init(key: String, modifiers: [ModifierKey]) {
        self.key = key
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        self.modifiers = Array(Set(modifiers)).sorted()
    }

    var debugDescription: String {
        userFacingDescription
    }

    var userFacingDescription: String {
        let parts = modifiers.map(\.displayName) + [key.capsNavDisplayKeyTitle]
        return parts.joined(separator: " + ")
    }
}

enum Output: Equatable {
    case builtin(action: BuiltinAction)
    case shortcut(Shortcut)

    var shortcutValue: Shortcut? {
        guard case let .shortcut(shortcut) = self else {
            return nil
        }

        return shortcut
    }
}

extension Output: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case action
        case shortcut
    }

    private enum OutputType: String, Codable {
        case builtin
        case shortcut
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(OutputType.self, forKey: .type)

        switch type {
        case .builtin:
            if container.contains(.shortcut) {
                throw ProfileValidationError.outputConflict("builtin output 不允许包含 shortcut 字段")
            }

            let action = try container.decode(BuiltinAction.self, forKey: .action)
            self = .builtin(action: action)

        case .shortcut:
            if container.contains(.action) {
                throw ProfileValidationError.outputConflict("shortcut output 不允许包含 action 字段")
            }

            let shortcut = try container.decode(Shortcut.self, forKey: .shortcut)
            self = .shortcut(shortcut)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .builtin(action):
            try container.encode(OutputType.builtin, forKey: .type)
            try container.encode(action, forKey: .action)

        case let .shortcut(shortcut):
            try container.encode(OutputType.shortcut, forKey: .type)
            try container.encode(shortcut, forKey: .shortcut)
        }
    }

    var debugDescription: String {
        switch self {
        case let .builtin(action):
            return action.displayName
        case let .shortcut(shortcut):
            return shortcut.debugDescription
        }
    }

    var userFacingDescription: String {
        switch self {
        case let .builtin(action):
            return action.displayName
        case let .shortcut(shortcut):
            return "发送 \(shortcut.userFacingDescription)"
        }
    }

    var suggestedDescription: String? {
        switch self {
        case let .builtin(action):
            return action.defaultShortcutDescription
        case let .shortcut(shortcut):
            return "发送 \(shortcut.userFacingDescription)"
        }
    }
}

enum BuiltinAction: String, Codable, CaseIterable, Equatable {
    case moveLeft
    case moveRight
    case moveUp
    case moveDown
    case selectLeft
    case selectRight
    case selectUp
    case selectDown
    case moveWordLeft
    case moveWordRight
    case selectWordLeft
    case selectWordRight
    case moveToLineStart
    case moveToLineEnd
    case selectToLineStart
    case selectToLineEnd
    case deleteBackward
    case deleteForward
    case deleteWordBackward
    case deleteWordForward

    var displayName: String {
        switch self {
        case .moveLeft:
            return "左移一个字符"
        case .moveRight:
            return "右移一个字符"
        case .moveUp:
            return "上移一行"
        case .moveDown:
            return "下移一行"
        case .selectLeft:
            return "向左选择一个字符"
        case .selectRight:
            return "向右选择一个字符"
        case .selectUp:
            return "向上选择一行"
        case .selectDown:
            return "向下选择一行"
        case .moveWordLeft:
            return "左移一个单词"
        case .moveWordRight:
            return "右移一个单词"
        case .selectWordLeft:
            return "向左选择一个单词"
        case .selectWordRight:
            return "向右选择一个单词"
        case .moveToLineStart:
            return "移动到行首"
        case .moveToLineEnd:
            return "移动到行尾"
        case .selectToLineStart:
            return "选择到行首"
        case .selectToLineEnd:
            return "选择到行尾"
        case .deleteBackward:
            return "删除前一个字符"
        case .deleteForward:
            return "删除后一个字符"
        case .deleteWordBackward:
            return "删除前一个单词"
        case .deleteWordForward:
            return "删除后一个单词"
        }
    }

    var defaultShortcutDescription: String {
        switch self {
        case .moveLeft:
            return "光标向左移动"
        case .moveRight:
            return "光标向右移动"
        case .moveUp:
            return "光标向上移动"
        case .moveDown:
            return "光标向下移动"
        case .selectLeft:
            return "向左选中一个"
        case .selectRight:
            return "向右选中一个"
        case .selectUp:
            return "向上选中（跨行）"
        case .selectDown:
            return "向下选中（跨行）"
        case .moveWordLeft:
            return "光标向左移动一个单词"
        case .moveWordRight:
            return "光标向右移动一个单词"
        case .selectWordLeft:
            return "向左选中一个单词"
        case .selectWordRight:
            return "向右选中一个单词"
        case .moveToLineStart:
            return "光标移动到行首"
        case .moveToLineEnd:
            return "光标移动到行尾"
        case .selectToLineStart:
            return "向左选中到行首"
        case .selectToLineEnd:
            return "向右选中到行尾"
        case .deleteBackward:
            return "向左删除一个"
        case .deleteForward:
            return "向右删除一个"
        case .deleteWordBackward:
            return "向左删除一个单词"
        case .deleteWordForward:
            return "向右删除一个单词"
        }
    }
}

enum ProfileValidationError: LocalizedError, Equatable {
    case emptyProfileIdentifier
    case emptyProfileName
    case emptyTriggerKey
    case duplicateTrigger(String)
    case outputConflict(String)

    var errorDescription: String? {
        switch self {
        case .emptyProfileIdentifier:
            return "profile.id 不能为空。"
        case .emptyProfileName:
            return "profile.name 不能为空。"
        case .emptyTriggerKey:
            return "trigger.key 不能为空。"
        case let .duplicateTrigger(triggerDescription):
            return "存在重复 trigger：\(triggerDescription)。"
        case let .outputConflict(message):
            return message
        }
    }
}

extension Profile {
    static let `default` = Profile(
        id: "default",
        name: "默认方案",
        version: 2,
        mappings: [
            .builtin("e", action: .moveUp, description: "光标向上移动"),
            .builtin("d", action: .moveDown, description: "光标向下移动"),
            .builtin("s", action: .moveLeft, description: "光标向左移动"),
            .builtin("f", action: .moveRight, description: "光标向右移动"),
            .builtin("a", action: .moveWordLeft, description: "光标向左移动一个单词"),
            .builtin("g", action: .moveWordRight, description: "光标向右移动一个单词"),
            .builtin("p", action: .moveToLineStart, description: "光标移动到行首"),
            .builtin(";", action: .moveToLineEnd, description: "光标移动到行尾"),
            .builtin("w", action: .deleteBackward, description: "向左删除一个"),
            .builtin("r", action: .deleteForward, description: "向右删除一个"),
            .builtin("q", action: .deleteWordBackward, description: "向左删除一个单词"),
            .builtin("t", action: .deleteWordForward, description: "向右删除一个单词"),
            .builtin("i", action: .selectUp, description: "向上选中（跨行）"),
            .builtin("k", action: .selectDown, description: "向下选中（跨行）"),
            .builtin("j", action: .selectLeft, description: "向左选中一个"),
            .builtin("l", action: .selectRight, description: "向右选中一个"),
            .builtin("h", action: .selectWordLeft, description: "向左选中一个单词"),
            .builtin("n", action: .selectWordRight, description: "向右选中一个单词"),
            .builtin("u", action: .selectToLineStart, description: "向左选中到行首"),
            .builtin("o", action: .selectToLineEnd, description: "向右选中到行尾")
        ]
    )

    static let legacyDefaultV1Mappings: [Mapping] = [
        .builtin("s", action: .moveLeft),
        .builtin("f", action: .moveRight),
        .builtin("e", action: .moveUp),
        .builtin("d", action: .moveDown),
        .builtin("s", modifiers: [.shift], action: .selectLeft),
        .builtin("f", modifiers: [.shift], action: .selectRight),
        .builtin("e", modifiers: [.shift], action: .selectUp),
        .builtin("d", modifiers: [.shift], action: .selectDown),
        .builtin("w", action: .moveWordLeft),
        .builtin("r", action: .moveWordRight),
        .builtin("w", modifiers: [.shift], action: .selectWordLeft),
        .builtin("r", modifiers: [.shift], action: .selectWordRight),
        .builtin("a", action: .moveToLineStart),
        .builtin("g", action: .moveToLineEnd),
        .builtin("a", modifiers: [.shift], action: .selectToLineStart),
        .builtin("g", modifiers: [.shift], action: .selectToLineEnd),
        .builtin("x", action: .deleteBackward),
        .builtin("c", action: .deleteForward),
        .builtin("x", modifiers: [.option], action: .deleteWordBackward),
        .shortcut("q", shortcutKey: "a", shortcutModifiers: [.control])
    ]

    var matchesLegacyDefaultV1: Bool {
        id == Self.default.id && version == 1 && mappings == Self.legacyDefaultV1Mappings
    }

    func backfilledDescriptions(using template: Profile) -> Profile {
        let templateDescriptions: [String: String] = Dictionary(
            uniqueKeysWithValues: template.mappings.compactMap { mapping in
                guard let description = mapping.persistedDescription else {
                    return nil
                }

                return (mapping.trigger.signature, description)
            }
        )

        let updatedMappings = mappings.map { mapping -> Mapping in
            guard mapping.persistedDescription == nil,
                  let templateDescription = templateDescriptions[mapping.trigger.signature] else {
                return mapping
            }

            return Mapping(
                trigger: mapping.trigger,
                output: mapping.output,
                description: templateDescription
            )
        }

        guard updatedMappings != mappings else {
            return self
        }

        return Profile(
            id: id,
            name: name,
            version: version,
            mappings: updatedMappings
        )
    }
}

extension Profile {
    func output(for trigger: Trigger) -> Output? {
        mappings.first(where: { $0.trigger == trigger })?.output
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension String {
    var capsNavDisplayKeyTitle: String {
        switch self {
        case "left":
            return "Left"
        case "right":
            return "Right"
        case "up":
            return "Up"
        case "down":
            return "Down"
        case "delete":
            return "Delete"
        case "forwardDelete":
            return "Forward Delete"
        case "return":
            return "Return"
        case "space":
            return "Space"
        case "tab":
            return "Tab"
        case "escape":
            return "Escape"
        default:
            return count == 1 ? uppercased() : self
        }
    }
}

private extension Mapping {
    static func builtin(
        _ key: String,
        modifiers: [ModifierKey] = [],
        action: BuiltinAction,
        description: String? = nil
    ) -> Mapping {
        Mapping(
            trigger: Trigger(key: key, modifiers: modifiers),
            output: .builtin(action: action),
            description: description
        )
    }

    static func shortcut(
        _ key: String,
        modifiers: [ModifierKey] = [],
        shortcutKey: String,
        shortcutModifiers: [ModifierKey],
        description: String? = nil
    ) -> Mapping {
        Mapping(
            trigger: Trigger(key: key, modifiers: modifiers),
            output: .shortcut(Shortcut(key: shortcutKey, modifiers: shortcutModifiers)),
            description: description
        )
    }
}

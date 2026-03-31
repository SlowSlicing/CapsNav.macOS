import SwiftUI

struct ReleaseNotesMarkdownView: View {
    let markdown: String

    private var blocks: [ReleaseNotesMarkdownBlock] {
        ReleaseNotesMarkdownParser.parse(markdown)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                ReleaseNotesMarkdownBlockView(block: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum ReleaseNotesMarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case unorderedList([String])
    case orderedList([ReleaseNotesOrderedListItem])
    case blockquote(String)
    case codeBlock(language: String?, code: String)
    case divider
}

struct ReleaseNotesOrderedListItem: Equatable {
    let marker: String
    let text: String
}

enum ReleaseNotesMarkdownParser {
    static func parse(_ markdown: String) -> [ReleaseNotesMarkdownBlock] {
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        var blocks: [ReleaseNotesMarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if let codeFence = parseCodeFence(lines: lines, startIndex: index) {
                blocks.append(codeFence.block)
                index = codeFence.nextIndex
                continue
            }

            if isDivider(trimmed) {
                blocks.append(.divider)
                index += 1
                continue
            }

            if let heading = parseHeading(trimmed) {
                blocks.append(heading)
                index += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                let quote = collectWhile(lines: lines, startIndex: index) { current in
                    current.trimmingCharacters(in: .whitespaces).hasPrefix(">")
                }
                let text = quote.lines
                    .map { line in
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        let dropped = trimmed.dropFirst()
                        return dropped.hasPrefix(" ") ? String(dropped.dropFirst()) : String(dropped)
                    }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    blocks.append(.blockquote(text))
                }
                index = quote.nextIndex
                continue
            }

            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                let list = collectWhile(lines: lines, startIndex: index) { current in
                    let trimmed = current.trimmingCharacters(in: .whitespaces)
                    return trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ")
                }
                let items = list.lines.map { line in
                    String(line.trimmingCharacters(in: .whitespaces).dropFirst(2))
                }
                blocks.append(.unorderedList(items))
                index = list.nextIndex
                continue
            }

            if orderedListMatch(for: trimmed) != nil {
                let list = collectWhile(lines: lines, startIndex: index) { current in
                    orderedListMatch(for: current.trimmingCharacters(in: .whitespaces)) != nil
                }
                let items = list.lines.compactMap { line -> ReleaseNotesOrderedListItem? in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard let match = orderedListMatch(for: trimmed) else {
                        return nil
                    }

                    return ReleaseNotesOrderedListItem(marker: match.marker, text: match.text)
                }
                blocks.append(.orderedList(items))
                index = list.nextIndex
                continue
            }

            let paragraph = collectWhile(lines: lines, startIndex: index) { current in
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else {
                    return false
                }

                return !trimmed.hasPrefix(">") &&
                    !trimmed.hasPrefix("- ") &&
                    !trimmed.hasPrefix("* ") &&
                    !trimmed.hasPrefix("+ ") &&
                    !trimmed.hasPrefix("```") &&
                    orderedListMatch(for: trimmed) == nil &&
                    parseHeading(trimmed) == nil &&
                    !isDivider(trimmed)
            }

            let text = paragraph.lines
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !text.isEmpty {
                blocks.append(.paragraph(text))
            }
            index = paragraph.nextIndex
        }

        return blocks
    }

    private static func parseHeading(_ line: String) -> ReleaseNotesMarkdownBlock? {
        let hashes = line.prefix { $0 == "#" }
        let level = hashes.count
        guard (1...6).contains(level), line.dropFirst(level).first == " " else {
            return nil
        }

        let text = line.dropFirst(level + 1).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            return nil
        }
        return .heading(level: level, text: text)
    }

    private static func parseCodeFence(lines: [String], startIndex: Int) -> (block: ReleaseNotesMarkdownBlock, nextIndex: Int)? {
        let trimmed = lines[startIndex].trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("```") else {
            return nil
        }

        let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        var codeLines: [String] = []
        var index = startIndex + 1

        while index < lines.count {
            let current = lines[index]
            if current.trimmingCharacters(in: .whitespaces) == "```" {
                return (
                    .codeBlock(language: language.isEmpty ? nil : language, code: codeLines.joined(separator: "\n")),
                    index + 1
                )
            }

            codeLines.append(current)
            index += 1
        }

        return (
            .codeBlock(language: language.isEmpty ? nil : language, code: codeLines.joined(separator: "\n")),
            lines.count
        )
    }

    private static func orderedListMatch(for line: String) -> (marker: String, text: String)? {
        let pattern = #"^(\d+\.)\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              let markerRange = Range(match.range(at: 1), in: line),
              let textRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        return (marker: String(line[markerRange]), text: String(line[textRange]))
    }

    private static func isDivider(_ line: String) -> Bool {
        line == "---" || line == "***" || line == "___"
    }

    private static func collectWhile(
        lines: [String],
        startIndex: Int,
        predicate: (String) -> Bool
    ) -> (lines: [String], nextIndex: Int) {
        var result: [String] = []
        var index = startIndex

        while index < lines.count, predicate(lines[index]) {
            result.append(lines[index])
            index += 1
        }

        return (result, index)
    }
}

private struct ReleaseNotesMarkdownBlockView: View {
    let block: ReleaseNotesMarkdownBlock

    var body: some View {
        switch block {
        case let .heading(level, text):
            Text(inlineMarkdown(text))
                .font(headingFont(for: level))
                .foregroundStyle(CapsNavTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

        case let .paragraph(text):
            Text(inlineMarkdown(text))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

        case let .unorderedList(items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text("•")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textMuted)
                            .padding(.top, 1)

                        Text(inlineMarkdown(item))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case let .orderedList(items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text(item.marker)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textMuted)
                            .frame(width: 28, alignment: .trailing)

                        Text(inlineMarkdown(item.text))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case let .blockquote(text):
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(CapsNavTheme.accentStrong.opacity(0.42))
                    .frame(width: 4)

                Text(inlineMarkdown(text))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(CapsNavTheme.surfaceSecondary)
            )

        case let .codeBlock(language, code):
            VStack(alignment: .leading, spacing: 10) {
                if let language, !language.isEmpty {
                    Text(language.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textMuted)
                }

                ScrollView(.horizontal, showsIndicators: true) {
                    Text(code)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(CapsNavTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(CapsNavTheme.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(CapsNavTheme.borderSoft.opacity(0.72), lineWidth: 1)
            )

        case .divider:
            Divider()
                .overlay(CapsNavTheme.borderSoft.opacity(0.92))
        }
    }

    private func inlineMarkdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1:
            return .system(size: 28, weight: .bold, design: .rounded)
        case 2:
            return .system(size: 23, weight: .bold, design: .rounded)
        case 3:
            return .system(size: 19, weight: .bold, design: .rounded)
        default:
            return .system(size: 17, weight: .semibold, design: .rounded)
        }
    }
}

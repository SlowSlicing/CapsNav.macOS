import Foundation

struct WeeklyTrendSummary {
    let totalCount: Int
    let averageCount: Int
    let peakRecord: DailyRecord?
}

enum StatisticsPresentationFormatter {
    private static let modifierOrder: [String] = ["control", "option", "shift", "command"]

    static func displayName(for signature: String) -> String {
        let components = signature.split(
            separator: "|",
            omittingEmptySubsequences: false
        ).map(String.init)

        let rawKey = components.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let key = rawKey.isEmpty ? "未知" : rawKey.uppercased()

        let modifiers = parsedModifiers(from: components.dropFirst().first)
        guard !modifiers.isEmpty else {
            return key
        }

        return modifiers.joined(separator: " + ") + " + " + key
    }

    static func weeklySummary(for records: [DailyRecord]) -> WeeklyTrendSummary {
        let totalCount = records.reduce(0) { $0 + $1.count }
        let averageCount = records.isEmpty
            ? 0
            : Int((Double(totalCount) / Double(records.count)).rounded())
        let peakRecord = records.max { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.date < rhs.date
            }
            return lhs.count < rhs.count
        }

        return WeeklyTrendSummary(
            totalCount: totalCount,
            averageCount: averageCount,
            peakRecord: peakRecord
        )
    }

    private static func parsedModifiers(from rawModifiers: String?) -> [String] {
        let modifiers = (rawModifiers ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        return modifierOrder.compactMap { modifier in
            guard modifiers.contains(modifier) else {
                return nil
            }
            return modifierDisplayName(modifier)
        }
    }

    private static func modifierDisplayName(_ modifier: String) -> String? {
        switch modifier {
        case "shift":
            return "Shift"
        case "control":
            return "Control"
        case "option":
            return "Option"
        case "command":
            return "Command"
        default:
            return nil
        }
    }
}

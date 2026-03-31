import Foundation

struct UsageStatistics: Codable, Equatable {
    var totalTriggerCount: Int
    var firstRecordedDate: Date?
    var dailyRecords: [DailyRecord]
    var triggerCounts: [String: Int]

    static let `default` = UsageStatistics(
        totalTriggerCount: 0,
        firstRecordedDate: nil,
        dailyRecords: [],
        triggerCounts: [:]
    )

    var todayRecord: DailyRecord? {
        let todayKey = Date().dayKey
        return dailyRecords.first(where: { $0.date == todayKey })
    }
}

struct DailyRecord: Codable, Equatable, Identifiable {
    let date: String
    var count: Int

    var id: String { date }
}

extension UsageStatistics {
    mutating func recordTrigger(signature: String) {
        totalTriggerCount += 1

        if firstRecordedDate == nil {
            firstRecordedDate = Date()
        }

        let todayKey = Date().dayKey

        if let index = dailyRecords.firstIndex(where: { $0.date == todayKey }) {
            dailyRecords[index].count += 1
        } else {
            dailyRecords.append(DailyRecord(date: todayKey, count: 1))
        }

        triggerCounts[signature, default: 0] += 1

        cleanupOldRecords()
    }

    mutating func cleanupOldRecords() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let cutoffKey = cutoffDate.dayKey

        dailyRecords.removeAll { $0.date < cutoffKey }
    }

    func sortedTriggerCounts(limit: Int = 10) -> [(signature: String, count: Int)] {
        triggerCounts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (signature: $0.key, count: $0.value) }
    }

    var recentDailyRecords: [DailyRecord] {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: Date()) ?? Date()

        var result: [DailyRecord] = []
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: sevenDaysAgo) else {
                continue
            }
            let dayKey = date.dayKey

            if let record = dailyRecords.first(where: { $0.date == dayKey }) {
                result.append(record)
            } else {
                result.append(DailyRecord(date: dayKey, count: 0))
            }
        }

        return result
    }
}

private extension Date {
    var dayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar.current
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }
}

import Foundation

@main
struct StatisticsPresentationSmokeTests {
    static func main() {
        testRecentDailyRecordsAlwaysReturnSevenDays()
        testDisplayNameStripsEmptyModifierSeparator()
        testDisplayNameFormatsModifiersInStableOrder()
        testWeeklySummaryCalculatesTotalAverageAndPeak()
        print("StatisticsPresentationSmokeTests passed")
    }

    private static func testRecentDailyRecordsAlwaysReturnSevenDays() {
        var statistics = UsageStatistics.default
        statistics.dailyRecords = [
            DailyRecord(date: dayKey(offsetFromToday: -2), count: 6),
            DailyRecord(date: dayKey(offsetFromToday: 0), count: 3)
        ]

        let records = statistics.recentDailyRecords

        assert(records.count == 7, "recentDailyRecords 必须始终返回最近 7 天")
        assert(records[4].count == 6, "两天前的数据应该保留")
        assert(records[6].count == 3, "今天的数据应该保留")
        assert(records[5].count == 0, "缺失日期应该自动补零")
    }

    private static func testDisplayNameStripsEmptyModifierSeparator() {
        let displayName = StatisticsPresentationFormatter.displayName(for: "f|")
        assert(displayName == "F", "无修饰键不应显示内部分隔符，实际为 \(displayName)")
    }

    private static func testDisplayNameFormatsModifiersInStableOrder() {
        let displayName = StatisticsPresentationFormatter.displayName(for: "f|option,shift,control")
        assert(displayName == "Control + Option + Shift + F", "修饰键展示顺序不稳定，实际为 \(displayName)")
    }

    private static func testWeeklySummaryCalculatesTotalAverageAndPeak() {
        let records = [
            DailyRecord(date: dayKey(offsetFromToday: -6), count: 2),
            DailyRecord(date: dayKey(offsetFromToday: -5), count: 5),
            DailyRecord(date: dayKey(offsetFromToday: -4), count: 0),
            DailyRecord(date: dayKey(offsetFromToday: -3), count: 9),
            DailyRecord(date: dayKey(offsetFromToday: -2), count: 4),
            DailyRecord(date: dayKey(offsetFromToday: -1), count: 6),
            DailyRecord(date: dayKey(offsetFromToday: 0), count: 1)
        ]

        let summary = StatisticsPresentationFormatter.weeklySummary(for: records)

        assert(summary.totalCount == 27, "最近 7 天总触发次数计算错误")
        assert(summary.averageCount == 4, "最近 7 天日均触发次数应向下取整")
        assert(summary.peakRecord?.count == 9, "最近 7 天峰值记录错误")
    }

    private static func dayKey(offsetFromToday offset: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = calendar
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}

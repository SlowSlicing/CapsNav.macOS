import Charts
import SwiftUI

struct StatisticsView: View {
    @ObservedObject var appBootstrap: AppBootstrap
    @State private var showResetConfirmation = false
    @State private var animateTrend = false

    private var statistics: UsageStatistics {
        appBootstrap.usageStatistics
    }

    private var todayCount: Int {
        statistics.todayRecord?.count ?? 0
    }

    private var continuousDays: Int {
        guard let firstDate = statistics.firstRecordedDate else {
            return 0
        }
        let days = Calendar.current.dateComponents([.day], from: firstDate, to: Date()).day ?? 0
        return max(days, 1)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                summaryCardsSection
                trendChartSection
                topMappingsSection
                benefitSection
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !animateTrend else {
                return
            }

            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.72, dampingFraction: 0.84)) {
                    animateTrend = true
                }
            }
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("使用统计")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textPrimary)

                Text("了解你的 Caps Nav 使用情况")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textSecondary)
            }

            Spacer()

            Button {
                showResetConfirmation = true
            } label: {
                Label("重置统计", systemImage: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .buttonStyle(.bordered)
            .alert("重置统计", isPresented: $showResetConfirmation) {
                Button("取消", role: .cancel) { }
                Button("重置", role: .destructive) {
                    appBootstrap.resetUsageStatistics()
                }
            } message: {
                Text("确定要清空所有统计数据吗？此操作不可撤销。")
            }
        }
    }

    private var summaryCardsSection: some View {
        HStack(spacing: 16) {
            SummaryCard(
                icon: "keyboard.fill",
                iconColor: CapsNavTheme.accentStrong,
                title: "总触发次数",
                value: "\(statistics.totalTriggerCount)",
                unit: "次"
            )

            SummaryCard(
                icon: "calendar.badge.clock",
                iconColor: CapsNavTheme.success,
                title: "今日触发",
                value: "\(todayCount)",
                unit: "次"
            )

            SummaryCard(
                icon: "flame.fill",
                iconColor: CapsNavTheme.warning,
                title: "连续使用",
                value: "\(continuousDays)",
                unit: "天"
            )
        }
    }

    private var trendChartSection: some View {
        let recentRecords = statistics.recentDailyRecords
        let summary = StatisticsPresentationFormatter.weeklySummary(for: recentRecords)

        return StatisticsCard(
            title: "最近 7 天",
            subtitle: trendSubtitle(summary: summary)
        ) {
            VStack(alignment: .leading, spacing: 18) {
                trendMetricTiles(summary: summary)

                if summary.totalCount == 0 {
                    emptyTrendState
                } else {
                    trendChart(records: recentRecords)
                }
            }
        }
    }

    private func trendMetricTiles(summary: WeeklyTrendSummary) -> some View {
        HStack(spacing: 12) {
            TrendMetricTile(
                icon: "sum",
                title: "7 天总计",
                value: "\(summary.totalCount)",
                detail: "次触发",
                tint: CapsNavTheme.accentStrong
            )

            TrendMetricTile(
                icon: "sparkle.magnifyingglass",
                title: "最活跃日",
                value: peakDayTitle(from: summary.peakRecord),
                detail: summary.peakRecord.map { "\($0.count) 次" } ?? "暂无数据",
                tint: CapsNavTheme.warning
            )

            TrendMetricTile(
                icon: "chart.line.uptrend.xyaxis",
                title: "日均触发",
                value: "\(summary.averageCount)",
                detail: "次 / 天",
                tint: CapsNavTheme.success
            )
        }
    }

    private var emptyTrendState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(CapsNavTheme.textMuted)

            Text("最近 7 天还没有触发记录")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textPrimary)

            Text("开始使用后，这里会显示趋势变化和活跃度。")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(CapsNavTheme.surfaceSecondary.opacity(0.82))
        )
    }

    private func trendChart(records: [DailyRecord]) -> some View {
        let animatedRecords = records.map {
            DailyRecord(date: $0.date, count: animateTrend ? $0.count : 0)
        }

        return Chart {
            ForEach(animatedRecords) { record in
                BarMark(
                    x: .value("日期", compactDateLabel(from: record.date)),
                    y: .value("次数", record.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            CapsNavTheme.accentSoft.opacity(0.92),
                            CapsNavTheme.accentStrong.opacity(0.9)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .opacity(record.count > 0 ? 1 : 0.45)

                LineMark(
                    x: .value("日期", compactDateLabel(from: record.date)),
                    y: .value("次数", record.count)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(CapsNavTheme.accentStrong)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("日期", compactDateLabel(from: record.date)),
                    y: .value("次数", record.count)
                )
                .foregroundStyle(CapsNavTheme.accentStrong)
                .symbolSize(record.count > 0 ? 48 : 24)
            }
        }
        .chartLegend(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                    .foregroundStyle(CapsNavTheme.borderSoft.opacity(0.55))
                AxisTick()
                    .foregroundStyle(CapsNavTheme.borderSoft.opacity(0.55))
                AxisValueLabel()
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textMuted)
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel()
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textMuted)
            }
        }
        .frame(height: 220)
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(CapsNavTheme.surfaceSecondary.opacity(0.82))
        )
    }

    private var topMappingsSection: some View {
        let topMappings = statistics.sortedTriggerCounts(limit: 10)
        let totalCount = statistics.totalTriggerCount

        return StatisticsCard(
            title: "常用映射 TOP 10",
            subtitle: "更高频的触发键会排在前面，方便你判断最常使用的导航习惯。"
        ) {
            VStack(spacing: 10) {
                if topMappings.isEmpty {
                    Text("暂无数据")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 28)
                } else {
                    ForEach(Array(topMappings.enumerated()), id: \.offset) { index, item in
                        MappingStatRow(
                            rank: index + 1,
                            signature: item.signature,
                            count: item.count,
                            percentage: totalCount > 0 ? Double(item.count) / Double(totalCount) : 0
                        )
                    }
                }
            }
        }
    }

    private var benefitSection: some View {
        StatisticsCard(
            title: "预估效益",
            subtitle: "按当前使用量估算，你已经明显减少了手部离开主键区的次数。"
        ) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(CapsNavTheme.warning.opacity(0.14))
                        .frame(width: 56, height: 56)

                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(CapsNavTheme.warning)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("约 \(statistics.totalTriggerCount * 2) 次")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textPrimary)

                    Text("相当于节省了手部移动到方向键区的动作")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textSecondary)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(CapsNavTheme.warning.opacity(0.08))
            )
        }
    }

    private func trendSubtitle(summary: WeeklyTrendSummary) -> String {
        guard summary.totalCount > 0 else {
            return "最近 7 天的数据会在这里形成趋势概览。"
        }

        let peakDay = peakDayTitle(from: summary.peakRecord)
        return "最近 7 天共 \(summary.totalCount) 次触发，峰值出现在\(peakDay)。"
    }

    private func peakDayTitle(from record: DailyRecord?) -> String {
        guard let record else {
            return "暂无"
        }
        return shortDateLabel(from: record.date)
    }

    private func shortDateLabel(from dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        }

        if calendar.isDateInYesterday(date) {
            return "昨天"
        }

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "M/d"
        return outputFormatter.string(from: date)
    }

    private func compactDateLabel(from dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今"
        }

        if calendar.isDateInYesterday(date) {
            return "昨"
        }

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "M/d"
        return outputFormatter.string(from: date)
    }
}

private struct StatisticsCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textPrimary)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textSecondary)
            }

            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(CapsNavTheme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(CapsNavTheme.borderSoft.opacity(0.95), lineWidth: 1)
        )
        .shadow(color: CapsNavTheme.cardShadow.opacity(0.9), radius: 16, x: 0, y: 10)
    }
}

private struct SummaryCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let unit: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textMuted)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textPrimary)

                    Text(unit)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textSecondary)
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(CapsNavTheme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(CapsNavTheme.borderSoft.opacity(0.88), lineWidth: 1)
        )
        .shadow(color: CapsNavTheme.cardShadow.opacity(0.72), radius: 12, x: 0, y: 8)
    }
}

private struct TrendMetricTile: View {
    let icon: String
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tint.opacity(0.14))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textMuted)

                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textPrimary)

                Text(detail)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(CapsNavTheme.surfaceSecondary.opacity(0.94))
        )
    }
}

private struct MappingStatRow: View {
    let rank: Int
    let signature: String
    let count: Int
    let percentage: Double

    private var displayName: String {
        StatisticsPresentationFormatter.displayName(for: signature)
    }

    private var keyParts: [String] {
        displayName
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        HStack(spacing: 14) {
            Text("\(rank)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(rank <= 3 ? CapsNavTheme.accentStrong : CapsNavTheme.textMuted)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(keyParts, id: \.self) { part in
                        MappingKeyChip(label: part)
                    }
                }

                Text("\(count) 次 (\(String(format: "%.1f", percentage * 100))%)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textMuted)
            }

            Spacer()

            RoundedRectangle(cornerRadius: 999)
                .fill(CapsNavTheme.accentStrong.opacity(0.15))
                .frame(width: 88, height: 8)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 999)
                        .fill(CapsNavTheme.accentStrong)
                        .frame(width: max(percentage * 88, 6), height: 8)
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(CapsNavTheme.surfaceSecondary.opacity(0.88))
        )
    }
}

private struct MappingKeyChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(CapsNavTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(CapsNavTheme.surfacePrimarySolid.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(CapsNavTheme.borderSoft.opacity(0.9), lineWidth: 1)
            )
    }
}

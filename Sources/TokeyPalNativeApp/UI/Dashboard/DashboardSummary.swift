import SwiftUI
import Charts
import TokeyPalNative

/// 标题右侧用量汇总:ALL-TIME / TODAY 两指标 + 30 天组合图。
struct DashboardSummary: View {
    let stats: UsageStats

    var body: some View {
        HStack(spacing: 0) {
            // 标题 → 指标 的弹性间距
            Spacer(minLength: 24)
            HStack(spacing: 14) {
                metric(title: "ALL-TIME", systemImage: "clock.arrow.circlepath", value: formatCompactTokens(stats.totals.totalTokens))
                metric(title: "TODAY", systemImage: "calendar", value: formatCompactTokens(stats.totals.todayTokens))
            }
            // TODAY → 图表 的弹性间距(与上面的间距等宽)
            Spacer(minLength: 24)
            DashboardUsageChart(series: dashboardChartSeries(daily: stats.daily, localDate: stats.localDate))
                .frame(maxWidth: .infinity)
                .frame(height: 78)
        }
    }

    private func metric(title: String, systemImage: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: systemImage).font(.system(size: 10, weight: .black))
                Text(title).font(.system(size: 10, weight: .black)).tracking(0.09 * 10)
            }
            .foregroundStyle(ThemeColor.primaryStrong.opacity(0.86))
            .fixedSize()
            Text(value)
                .font(.system(size: 23, weight: .black))
                .foregroundStyle(ThemeColor.onSurface)
                .lineLimit(1)
                .fixedSize()
        }
    }
}

/// 30 天组合图:日柱 + 累计折线/面积(各按峰值归一到 0...1 同轴);空数据显示提示。
struct DashboardUsageChart: View {
    let series: [DashboardChartPoint]

    var body: some View {
        let isEmpty = series.allSatisfy { $0.dayTokens <= 0 }
        ZStack {
            RoundedRectangle(cornerRadius: 16).stroke(ThemeColor.outlineSoft, lineWidth: 1)
            if isEmpty {
                Text("No usage data in the last 30 days")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(.sRGB, red: 89.0 / 255.0, green: 59.0 / 255.0, blue: 33.0 / 255.0, opacity: 0.42))
                    .textCase(.uppercase)
            } else {
                chart.padding(8)
            }
        }
    }

    private var chart: some View {
        let maxDay = max(1, series.map(\.dayTokens).max() ?? 1)
        let maxCum = max(1, series.map(\.cumulativeTokens).max() ?? 1)
        return Chart {
            ForEach(series, id: \.localDate) { point in
                BarMark(
                    x: .value("date", point.localDate),
                    y: .value("day", Double(point.dayTokens) / Double(maxDay))
                )
                .foregroundStyle(ThemeColor.primaryStrong.opacity(0.45))
            }
            ForEach(series, id: \.localDate) { point in
                AreaMark(
                    x: .value("date", point.localDate),
                    y: .value("cum", Double(point.cumulativeTokens) / Double(maxCum))
                )
                .foregroundStyle(ThemeColor.secondary.opacity(0.08))
            }
            ForEach(series, id: \.localDate) { point in
                LineMark(
                    x: .value("date", point.localDate),
                    y: .value("cum", Double(point.cumulativeTokens) / Double(maxCum))
                )
                .foregroundStyle(Color(hex: "#23856f"))
                .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...1)
    }
}

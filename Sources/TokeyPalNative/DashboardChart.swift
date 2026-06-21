import Foundation

/// Dashboard 30 天组合图的单个数据点:当日 token 与累计 token。
public struct DashboardChartPoint: Equatable, Sendable {
    public let localDate: String
    public let dayTokens: Int
    public let cumulativeTokens: Int

    public init(localDate: String, dayTokens: Int, cumulativeTokens: Int) {
        self.localDate = localDate
        self.dayTokens = dayTokens
        self.cumulativeTokens = cumulativeTokens
    }
}

private func parseDay(_ s: String) -> Date? {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "yyyy-MM-dd"
    return f.date(from: s)
}

/// 取以 `localDate` 结尾、长度 `windowDays` 的窗口内行,按日期升序,
/// 累计为逐日 dayTokens 的运行和。
public func dashboardChartSeries(
    daily: [UsageDailyTotal],
    localDate: String,
    windowDays: Int = 30
) -> [DashboardChartPoint] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
    guard let end = parseDay(localDate),
          let start = calendar.date(byAdding: .day, value: -(windowDays - 1), to: end)
    else { return [] }

    let inWindow = daily.compactMap { row -> (Date, UsageDailyTotal)? in
        guard let d = parseDay(row.localDate), d >= start, d <= end else { return nil }
        return (d, row)
    }.sorted { $0.0 < $1.0 }

    var running = 0
    return inWindow.map { _, row in
        running += max(0, row.totalTokens)
        return DashboardChartPoint(
            localDate: row.localDate,
            dayTokens: max(0, row.totalTokens),
            cumulativeTokens: running
        )
    }
}

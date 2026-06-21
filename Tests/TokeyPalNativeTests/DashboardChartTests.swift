import Testing
@testable import TokeyPalNative

private func daily(_ d: String, _ t: Int) -> UsageDailyTotal {
    UsageDailyTotal(localDate: d, totalTokens: t, totalCost: 0)
}

@Test func seriesKeepsOnlyWindowAndSortsAscending() {
    let rows = [daily("2026-05-01", 5), daily("2026-06-21", 10), daily("2026-06-20", 7)]
    let s = dashboardChartSeries(daily: rows, localDate: "2026-06-21", windowDays: 30)
    #expect(s.map(\.localDate) == ["2026-06-20", "2026-06-21"]) // 5/01 在 30 天窗口外
    #expect(s.first!.localDate < s.last!.localDate)
}

@Test func cumulativeIsRunningSumMonotonic() {
    let rows = [daily("2026-06-19", 3), daily("2026-06-20", 4), daily("2026-06-21", 5)]
    let s = dashboardChartSeries(daily: rows, localDate: "2026-06-21")
    #expect(s.map(\.dayTokens) == [3, 4, 5])
    #expect(s.map(\.cumulativeTokens) == [3, 7, 12])
    #expect(s.last!.cumulativeTokens == s.reduce(0) { $0 + $1.dayTokens })
    for i in 1..<s.count { #expect(s[i].cumulativeTokens >= s[i - 1].cumulativeTokens) }
}

@Test func emptyInputYieldsEmptySeries() {
    #expect(dashboardChartSeries(daily: [], localDate: "2026-06-21").isEmpty)
}

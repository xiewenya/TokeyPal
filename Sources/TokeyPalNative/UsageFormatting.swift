import Foundation

/// 紧凑 token 数:>=1B → x.xB,>=1M → x.xM,>=1K → x.xK,否则原数(负数按 0)。
/// 一位小数采用 round-half-away-from-zero(与既有伴侣气泡格式一致)。
public func formatCompactTokens(_ value: Int) -> String {
    let safe = max(0, value)
    if safe >= 1_000_000_000 { return "\(oneDecimalHalfAway(Double(safe) / 1_000_000_000))B" }
    if safe >= 1_000_000 { return "\(oneDecimalHalfAway(Double(safe) / 1_000_000))M" }
    if safe >= 1_000 { return "\(oneDecimalHalfAway(Double(safe) / 1_000))K" }
    return String(safe)
}

private func oneDecimalHalfAway(_ value: Double) -> String {
    let rounded = (value * 10).rounded(.toNearestOrAwayFromZero) / 10
    return String(format: "%.1f", rounded)
}

/// 紧凑货币:>=1000 → US$x.xK,否则 US$x.xx(负数按 0)。
public func formatCompactCost(_ value: Double) -> String {
    let safe = max(0, value)
    if safe >= 1_000 { return String(format: "US$%.1fK", safe / 1_000) }
    return String(format: "US$%.2f", safe)
}

/// 天数标签:0 → "0",1 → 单数,>1 → 复数。
public func formatDaysLabel(_ days: Int) -> String {
    if days == 1 { return "1 day" }
    return days > 0 ? "\(days) days" : "0"
}

/// 今日占比(0...100 整数);total<=0 返回 0。
public func usageSharePercent(value: Int, total: Int) -> Int {
    guard total > 0 else { return 0 }
    let pct = Int((Double(value) / Double(total) * 100).rounded())
    return min(100, max(0, pct))
}

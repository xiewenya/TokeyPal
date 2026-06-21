import Foundation

public func secondsFromMs(_ ms: Int) -> Int { Int((Double(ms) / 1000).rounded()) }
public func msFromSeconds(_ s: Int) -> Int { s * 1000 }
public func minutesFromMs(_ ms: Int) -> Int { Int((Double(ms) / 60_000).rounded()) }
public func msFromMinutes(_ m: Int) -> Int { m * 60_000 }

/// 轮询设置在表单中的秒 / 分上下限(由 PollingSettings.normalized 的 ms 边界换算)。
public enum PollingBounds {
    public static let idleSeconds = (30_000 / 1000)...(300_000 / 1000)
    public static let activeSeconds = (10_000 / 1000)...(60_000 / 1000)
    public static let activeWindowMinutes = (60_000 / 60_000)...(600_000 / 60_000)
}

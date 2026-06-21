import Foundation

public enum UsageActivityState: String, Equatable, Sendable {
    case idle
    case usageActive
    case highBurn
    case dataError
}

public struct UsagePollingState: Equatable, Sendable {
    public var previousTokens: Int
    public var currentTokens: Int
    public var activityState: UsageActivityState
    public var hasReadyBaseline: Bool
    public var lastPositiveDeltaAtMs: Int?
    public var snapshot: UsageSnapshot?

    public static let initial = UsagePollingState(
        previousTokens: 0,
        currentTokens: 0,
        activityState: .idle,
        hasReadyBaseline: false,
        lastPositiveDeltaAtMs: nil,
        snapshot: nil
    )
}

public struct UsagePollingController: Equatable, Sendable {
    public private(set) var state: UsagePollingState
    public private(set) var settings: PollingSettings
    public var highBurnThresholdTokens: Int
    public var highBurnWindowMs: Int

    public init(
        settings: PollingSettings,
        highBurnThresholdTokens: Int = 1_000_000,
        highBurnWindowMs: Int = 60_000,
        nowMs: () -> Int = { Int(Date().timeIntervalSince1970 * 1000) }
    ) {
        self.state = .initial
        self.settings = settings.normalized()
        self.highBurnThresholdTokens = highBurnThresholdTokens
        self.highBurnWindowMs = highBurnWindowMs
        _ = nowMs
    }

    public var nextIntervalMs: Int {
        switch state.activityState {
        case .idle, .dataError:
            return settings.idlePollingIntervalMs
        case .usageActive, .highBurn:
            return settings.activePollingIntervalMs
        }
    }

    public mutating func updateSettings(_ settings: PollingSettings) {
        self.settings = settings.normalized()
    }

    public mutating func record(snapshot: UsageSnapshot, nowMs: Int = Int(Date().timeIntervalSince1970 * 1000)) -> UsagePollingState {
        let currentTokens = max(0, snapshot.progressTokens)
        let recentTokenDelta: Int
        let activityState: UsageActivityState
        let lastPositiveDeltaAtMs: Int?

        if snapshot.dataStatus != "ready" {
            recentTokenDelta = 0
            activityState = .dataError
            lastPositiveDeltaAtMs = state.lastPositiveDeltaAtMs
        } else if !state.hasReadyBaseline {
            recentTokenDelta = 0
            activityState = .idle
            lastPositiveDeltaAtMs = state.lastPositiveDeltaAtMs
        } else {
            recentTokenDelta = max(0, currentTokens - state.currentTokens)
            lastPositiveDeltaAtMs = recentTokenDelta > 0 ? nowMs : state.lastPositiveDeltaAtMs
            if recentTokenDelta >= highBurnThresholdTokens {
                activityState = .highBurn
            } else if let lastPositiveDeltaAtMs, nowMs - lastPositiveDeltaAtMs <= settings.activeWindowMs {
                activityState = .usageActive
            } else {
                activityState = .idle
            }
        }

        var nextSnapshot = snapshot
        nextSnapshot.recentTokenDelta = recentTokenDelta
        state = UsagePollingState(
            previousTokens: state.currentTokens,
            currentTokens: currentTokens,
            activityState: activityState,
            hasReadyBaseline: state.hasReadyBaseline || snapshot.dataStatus == "ready",
            lastPositiveDeltaAtMs: lastPositiveDeltaAtMs,
            snapshot: nextSnapshot
        )
        return state
    }
}

public func formatTrayUsageTitle(_ tokens: Int) -> String {
    let safeTokens = max(0, tokens)
    if safeTokens == 0 {
        return ""
    }

    if safeTokens < 10_000 {
        return safeTokens.formatted(.number.locale(Locale(identifier: "en_US")))
    }

    if safeTokens < 1_000_000 {
        let roundedK = Double(safeTokens) / 1_000
        if Double(String(format: "%.1f", roundedK)) ?? roundedK >= 1_000 {
            return String(format: "%.1fM", Double(safeTokens) / 1_000_000)
        }
        return String(format: "%.1fK", roundedK)
    }

    if safeTokens < 1_000_000_000 {
        let roundedM = Double(safeTokens) / 1_000_000
        if Double(String(format: "%.1f", roundedM)) ?? roundedM >= 1_000 {
            return String(format: "%.1fB", Double(safeTokens) / 1_000_000_000)
        }
        return String(format: "%.1fM", roundedM)
    }

    return String(format: "%.1fB", Double(safeTokens) / 1_000_000_000)
}

import Testing
@testable import TokeyPalNative

@Test func trayUsageTitleFormatsTodayTokens() {
    #expect(formatTrayUsageTitle(0) == "")
    #expect(formatTrayUsageTitle(9999) == "9,999")
    #expect(formatTrayUsageTitle(12_300) == "12.3K")
    #expect(formatTrayUsageTitle(999_950) == "1.0M")
    #expect(formatTrayUsageTitle(1_500_000) == "1.5M")
    #expect(formatTrayUsageTitle(7_296_800_000) == "7.3B")
    #expect(formatTrayUsageTitle(1_000_000_000) == "1.0B")
}

@Test func pollingControllerUsesIdleIntervalForInitialReadyBaseline() {
    var controller = UsagePollingController(settings: .default, nowMs: { 1_000 })

    let state = controller.record(snapshot: snapshot(tokens: 100), nowMs: 1_000)

    #expect(state.activityState == .idle)
    #expect(state.snapshot?.recentTokenDelta == 0)
    #expect(controller.nextIntervalMs == TokeyPalSettings.default.polling.idlePollingIntervalMs)
}

@Test func pollingControllerUsesActiveIntervalAfterPositiveDelta() {
    var controller = UsagePollingController(settings: .default, nowMs: { 1_000 })
    _ = controller.record(snapshot: snapshot(tokens: 100), nowMs: 1_000)

    let state = controller.record(snapshot: snapshot(tokens: 150), nowMs: 2_000)

    #expect(state.activityState == .usageActive)
    #expect(state.snapshot?.recentTokenDelta == 50)
    #expect(controller.nextIntervalMs == TokeyPalSettings.default.polling.activePollingIntervalMs)
}

@Test func pollingControllerUsesIdleIntervalAfterSourceError() {
    var controller = UsagePollingController(settings: .default, nowMs: { 1_000 })

    let state = controller.record(snapshot: snapshot(tokens: 100, dataStatus: "source_error"), nowMs: 1_000)

    #expect(state.activityState == .dataError)
    #expect(controller.nextIntervalMs == TokeyPalSettings.default.polling.idlePollingIntervalMs)
}

private func snapshot(tokens: Int, dataStatus: String = "ready") -> UsageSnapshot {
    UsageSnapshot(
        localDate: "2026-06-18",
        progressTokens: tokens,
        exactTokens: tokens,
        estimatedTokens: 0,
        sources: ["ccusage"],
        dataStatus: dataStatus,
        accuracy: "exact",
        recentTokenDelta: 0
    )
}

import Testing
@testable import TokeyPalNative

@Test func msSecondsRoundTrip() {
    #expect(secondsFromMs(60_000) == 60)
    #expect(msFromSeconds(60) == 60_000)
    #expect(minutesFromMs(300_000) == 5)
    #expect(msFromMinutes(5) == 300_000)
}

@Test func boundsMatchPollingNormalization() {
    #expect(PollingBounds.idleSeconds == 30...300)
    #expect(PollingBounds.activeSeconds == 10...60)
    #expect(PollingBounds.activeWindowMinutes == 1...10)
    let clamped = PollingSettings(
        idlePollingIntervalMs: msFromSeconds(5),
        activePollingIntervalMs: msFromSeconds(999),
        activeWindowMs: msFromMinutes(99)
    ).normalized()
    #expect(clamped.idlePollingIntervalMs == 30_000)
    #expect(clamped.activePollingIntervalMs == 60_000)
    #expect(clamped.activeWindowMs == 600_000)
}

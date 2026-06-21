import Foundation
import Testing
@testable import TokeyPalNative

@Test func defaultSettingsMatchTokeyPalDefaults() async throws {
    let store = SettingsStore(settingsURL: temporarySettingsURL())
    let settings = try store.read()

    #expect(settings.polling.idlePollingIntervalMs == 60_000)
    #expect(settings.polling.activePollingIntervalMs == 10_000)
    #expect(settings.polling.activeWindowMs == 300_000)
    #expect(settings.blindBoxThresholds.stage2TokenThreshold == 1)
    #expect(settings.blindBoxThresholds.stage3TokenThreshold == 50_000_000)
    #expect(settings.blindBoxThresholds.stage4TokenThreshold == 500_000_000)
    #expect(settings.companion.locked == false)
    #expect(settings.companion.alwaysOnTop == true)
    #expect(settings.companion.size == .medium)
    #expect(settings.companion.sizePixels == 360)
    #expect(settings.usageApps["claude"] == true)
    #expect(settings.usageApps["codex"] == true)
    #expect(settings.usageApps["gemini"] == false)
}

@Test func writingSettingsMergesNestedValues() async throws {
    let store = SettingsStore(settingsURL: temporarySettingsURL())

    let updated = try store.update(TokeyPalSettingsUpdate(
        polling: PollingSettings(idlePollingIntervalMs: 5_000, activePollingIntervalMs: 99_000, activeWindowMs: 10),
        usageApps: ["claude": false, "gemini": true],
        usageAppDirectories: ["openclaw": ["/tmp/openclaw"]],
        companion: CompanionSettings(bounds: Bounds(x: 10, y: 20, width: 1, height: 1), locked: true, alwaysOnTop: false, size: .large)
    ))

    #expect(updated.polling.idlePollingIntervalMs == 30_000)
    #expect(updated.polling.activePollingIntervalMs == 60_000)
    #expect(updated.polling.activeWindowMs == 60_000)
    #expect(updated.usageApps["claude"] == false)
    #expect(updated.usageApps["codex"] == true)
    #expect(updated.usageApps["gemini"] == false)
    #expect(updated.usageAppDirectories["openclaw"] == ["/tmp/openclaw"])
    #expect(updated.companion.bounds?.x == 10)
    #expect(updated.companion.bounds?.width == 480)
    #expect(updated.companion.locked == true)
    #expect(updated.companion.alwaysOnTop == false)
    #expect(updated.companion.sizePixels == 480)
}

@Test func defaultOnboardingIsNotCompleted() async throws {
    let store = SettingsStore(settingsURL: temporarySettingsURL())
    let settings = try store.read()

    #expect(settings.onboarding.completed == false)
}

@Test func writingOnboardingCompletedPersistsAndPreservesOtherValues() async throws {
    let url = temporarySettingsURL()
    let store = SettingsStore(settingsURL: url)

    _ = try store.update(TokeyPalSettingsUpdate(usageApps: ["claude": false]))
    let updated = try store.update(TokeyPalSettingsUpdate(onboarding: OnboardingSettings(completed: true)))

    #expect(updated.onboarding.completed == true)
    #expect(updated.usageApps["claude"] == false)

    let reread = try store.read()
    #expect(reread.onboarding.completed == true)
    #expect(reread.usageApps["claude"] == false)
}

private func temporarySettingsURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("tokeypal-settings-\(UUID().uuidString)")
        .appendingPathExtension("json")
}

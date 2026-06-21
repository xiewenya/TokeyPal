import Foundation
import Testing
@testable import TokeyPalNative

@Test func completedUpdateSetsOnlyCompletion() {
    let u = onboardingCompletedUpdate()
    #expect(u.onboarding?.completed == true)
    #expect(u.usageApps == nil)
}

@Test func skipUpdateDisablesVisibleAppsAndCompletes() {
    let u = onboardingSkipUpdate()
    #expect(u.onboarding?.completed == true)
    let apps = u.usageApps ?? [:]
    for id in onboardingVisibleAppIds { #expect(apps[id] == false) }
}

@Test func appliedSkipPersistsDisabledVisibleApps() {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("ob-\(UUID().uuidString).json")
    let store = SettingsStore(settingsURL: url)
    let next = try! store.update(onboardingSkipUpdate())
    #expect(next.onboarding.completed)
    for id in onboardingVisibleAppIds { #expect(next.usageApps[id] == false) }
    try? FileManager.default.removeItem(at: url)
}

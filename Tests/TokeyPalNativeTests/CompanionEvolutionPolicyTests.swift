import Testing
@testable import TokeyPalNative

@Test func companionStageDecisionInitializesWithoutEvolution() {
    #expect(CompanionStageCoordinator.decision(displayedStage: nil, desiredStage: 2) == .initialize(stage: 2))
}

@Test func companionStageDecisionEvolvesOneStageAtATime() {
    #expect(CompanionStageCoordinator.decision(displayedStage: 2, desiredStage: 4) == .evolve(toStage: 3))
    #expect(CompanionStageCoordinator.decision(displayedStage: 3, desiredStage: 4) == .evolve(toStage: 4))
}

@Test func companionStageDecisionDowngradesImmediately() {
    #expect(CompanionStageCoordinator.decision(displayedStage: 4, desiredStage: 2) == .downgrade(toStage: 2))
}

@Test func companionStageDecisionLeavesSameStageUnchanged() {
    #expect(CompanionStageCoordinator.decision(displayedStage: 3, desiredStage: 3) == .unchanged(stage: 3))
}

@Test func companionStageDecisionClampsStagesToSupportedRange() {
    #expect(CompanionStageCoordinator.decision(displayedStage: nil, desiredStage: 99) == .initialize(stage: 4))
    #expect(CompanionStageCoordinator.decision(displayedStage: 0, desiredStage: 2) == .evolve(toStage: 2))
    #expect(CompanionStageCoordinator.decision(displayedStage: 2, desiredStage: 0) == .downgrade(toStage: 1))
}

@Test func companionUsageAffectingSettingsDetectsRelevantChanges() {
    let before = TokeyPalSettings.default
    var after = before

    after.usageApps["codex"] = false
    #expect(companionUsageAffectingSettingsChanged(from: before, to: after))

    after = before
    after.usageAppDirectories["codex"] = ["/tmp/codex"]
    #expect(companionUsageAffectingSettingsChanged(from: before, to: after))

    after = before
    after.blindBoxThresholds = BlindBoxThresholds(stage2TokenThreshold: 2, stage3TokenThreshold: 3, stage4TokenThreshold: 4)
    #expect(companionUsageAffectingSettingsChanged(from: before, to: after))

    after = before
    after.companion = CompanionSettings(bounds: nil, locked: true, alwaysOnTop: before.companion.alwaysOnTop, size: before.companion.size)
    #expect(!companionUsageAffectingSettingsChanged(from: before, to: after))
}

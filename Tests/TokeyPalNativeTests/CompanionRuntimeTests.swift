import Foundation
import Testing
@testable import TokeyPalNative

private func projectRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

@Test func companionRuntimeResolvesStartEggAndTRexStage() throws {
    let resources = ResourceLocator(projectRoot: projectRoot())
    let runtime = try CompanionRuntime(resources: resources)

    let egg = try runtime.resolve(todayTokens: 0, settings: .default)
    #expect(egg.characterId == "t-rex")
    #expect(egg.displayStage == 1)
    #expect(egg.startType == "egg")
    #expect(egg.coverUrl.hasSuffix("/assets/start/egg/card.png"))
    #expect(egg.animationUrl == nil)

    var settings = TokeyPalSettings.default
    settings.blindBoxThresholds = BlindBoxThresholds(stage2TokenThreshold: 1, stage3TokenThreshold: 1000, stage4TokenThreshold: 2000)
    let trex = try runtime.resolve(todayTokens: 5, settings: settings)
    #expect(trex.characterId == "t-rex")
    #expect(trex.displayStage == 2)
    #expect(trex.coverUrl.hasSuffix("/data/t-rex/2/card.png"))
    #expect(trex.characterUrl?.hasSuffix("/data/t-rex/2/cover.png") == true)
}

@Test func companionDisplayUrlPrefersAnimationBeforeStaticCharacter() {
    let state = CompanionState(
        characterId: "t-rex",
        characterName: "t-rex",
        displayStage: 2,
        startType: "egg",
        action: nil,
        sizePixels: 360,
        animationUrl: "file:///animation.webp",
        coverUrl: "file:///cover.png",
        characterUrl: "file:///character.png"
    )

    #expect(companionDisplayUrl(from: state) == URL(string: "file:///animation.webp"))
}

@Test func companionRuntimeUsesIdleAnimationForUnlockedStages() throws {
    let resources = ResourceLocator(projectRoot: projectRoot())
    let runtime = try CompanionRuntime(resources: resources)
    var settings = TokeyPalSettings.default
    settings.blindBoxThresholds = BlindBoxThresholds(stage2TokenThreshold: 1, stage3TokenThreshold: 1000, stage4TokenThreshold: 2000)

    let trex = try runtime.resolve(todayTokens: 5, settings: settings, action: "idle")

    let idleAnimations = ["/data/t-rex/2/howl.webp", "/data/t-rex/2/walk.webp"]
    #expect(idleAnimations.contains { trex.animationUrl?.hasSuffix($0) == true })
}

@Test func selectRandomAssetMatchesElectronIndexing() {
    #expect(selectRandomAsset(["a.webp", "b.webp", "c.webp"], random: { 0.6 }) == "b.webp")
    #expect(selectRandomAsset([], random: { 0.6 }) == nil)
}

@Test func companionRuntimePersistsManualSelectionAndBlindBoxMode() throws {
    let resources = ResourceLocator(projectRoot: projectRoot())
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let stateURL = directory.appendingPathComponent("blind-box-state.json")

    let runtime = try CompanionRuntime(resources: resources, stateURL: stateURL)
    try runtime.selectCharacter("t-rex")

    let restored = try CompanionRuntime(resources: resources, stateURL: stateURL)
    let state = try restored.resolve(todayTokens: 0, settings: .default)
    let view = try restored.buildBlindBoxView(todayTokens: 0, settings: .default)

    #expect(state.characterId == "t-rex")
    #expect(view.currentMode.blindBoxModeEnabled == false)
}

@Test func companionRuntimePersistsBlindBoxModeToggle() throws {
    let resources = ResourceLocator(projectRoot: projectRoot())
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let stateURL = directory.appendingPathComponent("blind-box-state.json")

    let runtime = try CompanionRuntime(resources: resources, stateURL: stateURL)
    runtime.setBlindBoxMode(false)

    let restored = try CompanionRuntime(resources: resources, stateURL: stateURL)
    let view = try restored.buildBlindBoxView(todayTokens: 0, settings: .default)

    #expect(view.currentMode.blindBoxModeEnabled == false)
}

@Test func companionRuntimeBuildsDebugManifestsView() throws {
    let resources = ResourceLocator(projectRoot: projectRoot())
    let runtime = try CompanionRuntime(resources: resources)

    let view = runtime.debugManifestsView()

    let trex = try #require(view.characters.first(where: { $0.id == "t-rex" }))
    #expect(trex.stages.contains(where: { $0.stage == 2 }))
    #expect(trex.stages.flatMap(\.actions).contains(where: { $0.action == "idle" && !$0.urls.isEmpty }))
}

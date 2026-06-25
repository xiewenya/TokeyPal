import Foundation
import Testing

@Test func companionPanelUsesPixelHitTestingAndContextMenu() throws {
    let source = try companionPanelControllerSource()

    #expect(source.contains("override func hitTest(_ point: NSPoint) -> NSView?"))
    #expect(source.contains("companionImagePixelCoordinate"))
    #expect(source.contains("companionImageAlphaCapturesMouse"))
    #expect(source.contains("capturesWindowPoint"))
    #expect(source.contains("updateMousePassthrough"))
    #expect(source.contains("NSEvent.addGlobalMonitorForEvents"))
    #expect(source.contains("pointerIsOverCompanion"))
    #expect(source.contains("handlePointerEntered"))
    #expect(source.contains("handlePointerExited"))
    #expect(source.contains("contextMenuProvider"))
    #expect(source.contains("override func rightMouseDown"))
}

@Test func companionBubbleIsNonInteractiveAndTracksVisibleImageBounds() throws {
    let source = try companionPanelControllerSource()

    #expect(source.contains("CompanionBubbleLabel"))
    #expect(source.contains("override func hitTest(_ point: NSPoint) -> NSView? { nil }"))
    #expect(source.contains("bubbleLabelTopConstraint"))
    #expect(source.contains("updateTokenBubblePosition()"))
    #expect(source.contains("imageView.visibleContentBounds()"))
    #expect(source.contains("gap: 30"))
    #expect(source.contains("bubbleLabel.heightAnchor.constraint(equalToConstant: 44)"))
    #expect(source.contains("horizontalTextPadding: CGFloat = 24"))
    #expect(source.contains("verticalTextPadding: CGFloat = 8"))
}

@Test func companionPanelHonorsStackingAndSizeSettings() throws {
    let source = try companionPanelControllerSource()

    #expect(!source.contains("orderFrontRegardless"))
    #expect(!source.contains(".stationary"))
    #expect(source.contains("panel.isFloatingPanel = currentSettings.companion.alwaysOnTop"))
    #expect(source.contains("panel.level = currentSettings.companion.alwaysOnTop ? .floating : .normal"))
    #expect(source.contains("panel.collectionBehavior = currentSettings.companion.alwaysOnTop"))
    #expect(source.contains("? [.canJoinAllSpaces, .fullScreenAuxiliary]"))
    #expect(source.contains(": []"))
    #expect(source.contains("applyWindowLevel()"))
    #expect(source.contains("applyWindowOrdering(previousAlwaysOnTop: previousAlwaysOnTop)"))
    #expect(source.contains("panel.orderBack(nil)"))
    #expect(source.contains("panel.orderOut(nil)"))
    #expect(source.contains("applyDisabledOrdering()"))
    #expect(source.contains("isPanelOnFullScreenSpace()"))
    #expect(source.contains("startWindowOrderingMonitoring()"))
    #expect(source.contains("NSWorkspace.didActivateApplicationNotification"))
    #expect(source.contains("NSWorkspace.activeSpaceDidChangeNotification"))
    #expect(source.contains("handleWorkspaceActivation"))
    #expect(source.contains("handleWorkspaceSpaceChange"))
    #expect(source.contains("pendingSizeChangeCenter"))
    #expect(source.contains("let preservesCenter = !usePersistedPosition"))
    #expect(source.contains("preservesCenter: preservesCenter"))
    #expect(source.contains("persistBounds(visibleLogicalBounds, normalize: !preservesCenter)"))
    #expect(source.contains("logicalBoundsForCenter(resizeCenter, sizePixels: settings.companion.sizePixels)"))
    #expect(source.contains("pendingSizeChangeCenter ?? centerPoint(for: logicalBoundsAnchor ?? currentLogicalBounds())"))
    #expect(source.contains("preservesCenter: true"))
    #expect(source.contains("persistBounds(visibleLogicalBounds, normalize: false)"))
    #expect(source.contains("persistBounds(logicalBoundsForCenter(resizeCenter, sizePixels: currentSettings.companion.sizePixels), normalize: false)"))
    #expect(source.contains("refreshImage()"))
    #expect(!source.contains("refreshImage(todayTokens: latestTodayTokens)"))
}

@Test func companionPanelRoutesUsageSnapshotsThroughDisplayedStageState() throws {
    let source = try companionPanelControllerSource()

    #expect(source.contains("private var displayedStage: Int?"))
    #expect(source.contains("func acceptUsageSnapshot(stats: UsageStats, settings: TokeyPalSettings)"))
    #expect(source.contains("CompanionStageCoordinator.decision(displayedStage: displayedStage, desiredStage: desiredStage)"))
    #expect(source.contains("case .evolve(let toStage):"))
    #expect(source.contains("triggerCompanionAction(\"evolve\", stage: toStage, confirmedStage: toStage)"))
    #expect(source.contains("self.displayedStage = confirmedStage"))
    #expect(!source.contains("displayedStage = toStage\n            triggerCompanionAction(\"evolve\")"))
    #expect(source.contains("case .downgrade(let toStage):"))
    #expect(source.contains("actionLoopObservation = nil"))
    #expect(source.contains("_ = interaction.clearAction()"))
    #expect(source.contains("showStaticCompanion(stage: toStage, settings: settings)"))
    #expect(source.contains("case .unchanged:"))
    #expect(source.contains("updateTokenBubblePosition()"))
    #expect(source.contains("runtime.resolve(displayStage: stage, settings: currentSettings, action: action)"))
    #expect(source.contains("@discardableResult\n    private func triggerCompanionAction(_ action: String, stage requestedStage: Int? = nil, confirmedStage: Int? = nil) -> Bool"))
    #expect(source.contains("guard let image else"))
    #expect(source.contains("_ = self.interaction.clearAction()"))
    #expect(!source.contains("runtime.resolve(todayTokens: latestTodayTokens, settings: currentSettings, action: interaction.currentAction)"))
    #expect(!source.contains("refreshImage(todayTokens: latestTodayTokens)"))
}

@Test func companionPanelStaticRefreshClearsActionState() throws {
    let source = try companionPanelControllerSource()

    #expect(source.contains("actionLoopObservation = nil\n        _ = interaction.clearAction()\n        showStaticCompanion(stage: stage, settings: currentSettings)"))
}

@Test func companionAnimationLoopReturnsToDisplayedStageStaticImage() throws {
    let source = try companionPanelControllerSource()

    #expect(source.contains("self.actionLoopObservation = nil"))
    #expect(source.contains("self.showStaticCompanion(stage: stage, settings: self.currentSettings)"))
    #expect(!source.contains("self.refreshImage(todayTokens: self.latestTodayTokens)"))
}

@Test func appDelegateProvidesCompanionContextMenu() throws {
    let source = try appDelegateSource()

    #expect(source.contains("companionPanel.contextMenuProvider"))
    #expect(source.contains("self?.buildMenu()"))
}

@Test func appDelegateRoutesOnlyAcceptedUsageSnapshotsToEvolution() throws {
    let source = try appDelegateSource()

    #expect(source.contains("private var latestCompanionSettings: TokeyPalSettings?"))
    #expect(source.contains("private var settingsGeneration = 0"))
    #expect(source.contains("store.settingsDidChange = { [weak self] settings in\n                self?.handleSettingsChanged(settings)\n            }"))
    #expect(source.contains("private func handleSettingsChanged(_ settings: TokeyPalSettings)"))
    #expect(source.contains("settingsGeneration += 1"))
    #expect(source.contains("usagePolling.updateSettings(settings.polling)"))
    #expect(source.contains("DispatchQueue.global(qos: .utility).async"))
    #expect(source.contains("handleUsageRefresh(result, settingsGeneration: requestGeneration)"))
    #expect(source.contains("guard requestGeneration == settingsGeneration"))
    #expect(source.contains("companionUsageAffectingSettingsChanged(from: previous, to: settings)"))
    #expect(source.contains("private func handleSettingsUsageRefresh(_ result: Result<UsageStats, Error>, settings: TokeyPalSettings, settingsGeneration requestGeneration: Int)"))
    #expect(source.components(separatedBy: "companionPanel?.acceptUsageSnapshot(stats: stats, settings: settings)").count - 1 == 2)
    #expect(!source.contains("companionPanel?.refreshImage(todayTokens:"))
    #expect(!source.contains("companionPanel?.refreshImage()"))
}

private func companionPanelControllerSource() throws -> String {
    try sourceFile("Sources/TokeyPalNativeApp/CompanionPanelController.swift")
}

private func appDelegateSource() throws -> String {
    try sourceFile("Sources/TokeyPalNativeApp/AppDelegate.swift")
}

private func sourceFile(_ relativePath: String) throws -> String {
    let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(
        contentsOf: projectRoot.appendingPathComponent(relativePath),
        encoding: .utf8
    )
}

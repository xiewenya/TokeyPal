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
    #expect(source.contains("applyWindowLevel()"))
    #expect(source.contains("applyWindowOrdering(previousAlwaysOnTop: previousAlwaysOnTop)"))
    #expect(source.contains("panel.orderBack(nil)"))
    #expect(source.contains("startWindowOrderingMonitoring()"))
    #expect(source.contains("NSWorkspace.didActivateApplicationNotification"))
    #expect(source.contains("handleWorkspaceActivation"))
    #expect(source.contains("pendingSizeChangeCenter"))
    #expect(source.contains("let preservesCenter = !usePersistedPosition"))
    #expect(source.contains("preservesCenter: preservesCenter"))
    #expect(source.contains("persistBounds(visibleLogicalBounds, normalize: !preservesCenter)"))
    #expect(source.contains("logicalBoundsForCenter(resizeCenter, sizePixels: settings.companion.sizePixels)"))
    #expect(source.contains("pendingSizeChangeCenter ?? centerPoint(for: logicalBoundsAnchor ?? currentLogicalBounds())"))
    #expect(source.contains("preservesCenter: true"))
    #expect(source.contains("persistBounds(visibleLogicalBounds, normalize: false)"))
    #expect(source.contains("persistBounds(logicalBoundsForCenter(resizeCenter, sizePixels: currentSettings.companion.sizePixels), normalize: false)"))
    #expect(source.contains("refreshImage(todayTokens: latestTodayTokens)"))
}

@Test func appDelegateProvidesCompanionContextMenu() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = try String(
        contentsOf: projectRoot.appendingPathComponent("Sources/TokeyPalNativeApp/AppDelegate.swift"),
        encoding: .utf8
    )

    #expect(source.contains("companionPanel.contextMenuProvider"))
    #expect(source.contains("self?.buildMenu()"))
}

private func companionPanelControllerSource() throws -> String {
    let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(
        contentsOf: projectRoot.appendingPathComponent("Sources/TokeyPalNativeApp/CompanionPanelController.swift"),
        encoding: .utf8
    )
}

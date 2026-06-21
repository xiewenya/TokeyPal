import AppKit
import Foundation
import SDWebImage
import TokeyPalNative

@MainActor
final class CompanionPanelController {
    private let settingsStore: SettingsStore
    private let usageService: UsageService
    private let runtime: CompanionRuntime
    private let panel: NSPanel
    private let contentView: NSView
    private let imageView: CompanionImageView
    private let bubbleLabel: NSTextField
    private var contentWidthConstraint: NSLayoutConstraint?
    private var contentHeightConstraint: NSLayoutConstraint?
    private var bubbleLabelTopConstraint: NSLayoutConstraint?
    private var currentSettings: TokeyPalSettings
    private var dragState: CompanionDragState?
    private var latestTodayTokens = 0
    private var interaction = CompanionInteraction()
    private var actionLoopObservation: NSKeyValueObservation?
    private var idleActionTimer: Timer?
    private var hasAppliedInitialBounds = false
    private var currentImageAspectRatio: Double?
    private var logicalBoundsAnchor: Bounds?
    private var pendingSizeChangeCenter: ScreenPoint?
    private var workspaceActivationObserver: Any?
    private var screenParametersObserver: Any?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var pointerIsOverCompanion = false

    var contextMenuProvider: (() -> NSMenu)? {
        get { imageView.contextMenuProvider }
        set { imageView.contextMenuProvider = newValue }
    }

    init(settingsStore: SettingsStore, usageService: UsageService, runtime: CompanionRuntime) throws {
        self.settingsStore = settingsStore
        self.usageService = usageService
        self.runtime = runtime
        self.currentSettings = try settingsStore.read()
        self.contentView = CompanionContainerView(frame: .zero)
        self.imageView = CompanionImageView(frame: .zero)
        self.bubbleLabel = CompanionBubbleLabel(labelWithString: "")
        self.panel = NSPanel(
            contentRect: NSRect(x: 80, y: 160, width: currentSettings.companion.sizePixels, height: currentSettings.companion.sizePixels),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.title = "TokeyPal Companion"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = contentView

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imageView.animates = true
        imageView.autoPlayAnimatedImage = true
        imageView.shouldCustomLoopCount = true
        imageView.animationRepeatCount = 1
        imageView.maxBufferSize = 1
        imageView.translatesAutoresizingMaskIntoConstraints = false
        bubbleLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleLabel.isHidden = true
        bubbleLabel.cell = CompanionBubbleCell(textCell: "")
        bubbleLabel.alignment = .center
        bubbleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        bubbleLabel.textColor = NSColor(calibratedRed: 0.13, green: 0.07, blue: 0.03, alpha: 1)
        bubbleLabel.backgroundColor = NSColor(calibratedRed: 1, green: 0.95, blue: 0.84, alpha: 0.96)
        bubbleLabel.isBezeled = false
        bubbleLabel.drawsBackground = true
        bubbleLabel.wantsLayer = true
        bubbleLabel.layer?.cornerRadius = 22
        bubbleLabel.layer?.masksToBounds = true
        bubbleLabel.cell?.alignment = .center
        bubbleLabel.cell?.lineBreakMode = .byClipping
        bubbleLabel.cell?.usesSingleLineMode = true
        contentView.addSubview(imageView)
        contentView.addSubview(bubbleLabel)
        let contentWidthConstraint = contentView.widthAnchor.constraint(equalToConstant: CGFloat(currentSettings.companion.sizePixels))
        let contentHeightConstraint = contentView.heightAnchor.constraint(equalToConstant: CGFloat(currentSettings.companion.sizePixels))
        let bubbleTopConstraint = bubbleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 72)
        self.contentWidthConstraint = contentWidthConstraint
        self.contentHeightConstraint = contentHeightConstraint
        bubbleLabelTopConstraint = bubbleTopConstraint
        NSLayoutConstraint.activate([
            contentWidthConstraint,
            contentHeightConstraint,
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.heightAnchor.constraint(equalTo: contentView.heightAnchor),
            bubbleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            bubbleTopConstraint,
            bubbleLabel.heightAnchor.constraint(equalToConstant: 44),
            bubbleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])
        imageView.dragStarted = { [weak self] point in
            self?.startDrag(point: point)
        }
        imageView.dragMoved = { [weak self] point in
            self?.movePanel(to: point)
        }
        imageView.dragEnded = { [weak self] in
            self?.endDrag()
            self?.persistBounds()
        }
        imageView.pointerEntered = { [weak self] in
            self?.handlePointerEntered()
        }
        imageView.pointerExited = { [weak self] in
            self?.handlePointerExited()
        }
        imageView.clicked = { [weak self] in
            self?.triggerCompanionAction("click")
        }

        startWindowOrderingMonitoring()
        startScreenChangeMonitoring()
        startMousePassthroughMonitoring()
        startIdleActionTimer()
        apply(settings: currentSettings)
        refreshImage()
    }

    func show() {
        refreshImage()
        if currentSettings.companion.alwaysOnTop {
            panel.orderFront(nil)
        } else {
            panel.orderBack(nil)
        }
    }

    func hide() {
        panel.orderOut(nil)
    }

    func apply(settings: TokeyPalSettings) {
        let previousSize = currentSettings.companion.sizePixels
        let previousAlwaysOnTop = currentSettings.companion.alwaysOnTop
        let sizeChanged = previousSize != settings.companion.sizePixels
        let usePersistedPosition = !hasAppliedInitialBounds
        let logicalBounds: Bounds
        if usePersistedPosition, let bounds = settings.companion.bounds {
            logicalBounds = Bounds(
                x: bounds.x,
                y: bounds.y,
                width: settings.companion.sizePixels,
                height: settings.companion.sizePixels
            )
            hasAppliedInitialBounds = true
        } else {
            logicalBounds = companionBoundsForAspect(
                center: panelCenter(),
                imageHeight: settings.companion.sizePixels,
                aspectRatio: 1
            )
            if usePersistedPosition {
                hasAppliedInitialBounds = true
            }
        }

        let preservesCenter = !usePersistedPosition
        let resizeCenter: ScreenPoint
        if preservesCenter {
            resizeCenter = centerPoint(for: logicalBoundsAnchor ?? currentLogicalBounds())
        } else if companionBoundsIntersectAnyWorkArea(bounds: logicalBounds, workAreas: companionScreenWorkAreas()) {
            // Persisted position is still on an available screen; keep it as-is
            // (resizeCompanionPanel applies an edge safety clamp afterwards).
            resizeCenter = centerPoint(for: logicalBounds)
        } else {
            // Persisted bounds reference a display that is no longer connected
            // (e.g. an external monitor that was unplugged). Recover them onto a
            // currently-available screen, keeping a margin from the edges so the
            // companion is not jammed into a corner.
            let recoveredBounds = normalizeCompanionBoundsForScreens(logicalBounds, margin: companionRecoveryMargin)
            resizeCenter = centerPoint(for: recoveredBounds)
        }
        if sizeChanged {
            pendingSizeChangeCenter = resizeCenter
        }

        currentSettings = settings
        resizeCompanionPanel(
            center: resizeCenter,
            aspectRatio: currentImageAspectRatio ?? 1,
            preservesCenter: preservesCenter
        )
        let visibleLogicalBounds = logicalBoundsForCenter(resizeCenter, sizePixels: settings.companion.sizePixels)
        logicalBoundsAnchor = visibleLogicalBounds
        contentView.layoutSubtreeIfNeeded()
        imageView.needsDisplay = true
        applyWindowLevel()
        applyWindowOrdering(previousAlwaysOnTop: previousAlwaysOnTop)
        imageView.isLocked = settings.companion.locked
        refreshImage(todayTokens: latestTodayTokens)
        updateMousePassthrough(screenPoint: NSEvent.mouseLocation)

        if sizeChanged || settings.companion.bounds != visibleLogicalBounds {
            persistBounds(visibleLogicalBounds, normalize: !preservesCenter)
        }
    }

    func toggleLock(_ locked: Bool) {
        if let settings = try? settingsStore.update(TokeyPalSettingsUpdate(
            companion: CompanionSettings(
                bounds: currentLogicalBounds(),
                locked: locked,
                alwaysOnTop: currentSettings.companion.alwaysOnTop,
                size: currentSettings.companion.size
            )
        )) {
            apply(settings: settings)
        }
    }

    /// Current companion settings, used by the tray/context menu to reflect the
    /// active size and always-on-top selections.
    var companionSettings: CompanionSettings {
        currentSettings.companion
    }

    func setSize(_ size: CompanionSizeMode) {
        guard size != currentSettings.companion.size else {
            return
        }
        if let settings = try? settingsStore.update(TokeyPalSettingsUpdate(
            companion: CompanionSettings(
                bounds: currentLogicalBounds(),
                locked: currentSettings.companion.locked,
                alwaysOnTop: currentSettings.companion.alwaysOnTop,
                size: size
            )
        )) {
            apply(settings: settings)
        }
    }

    func setAlwaysOnTop(_ enabled: Bool) {
        guard enabled != currentSettings.companion.alwaysOnTop else {
            return
        }
        if let settings = try? settingsStore.update(TokeyPalSettingsUpdate(
            companion: CompanionSettings(
                bounds: currentLogicalBounds(),
                locked: currentSettings.companion.locked,
                alwaysOnTop: enabled,
                size: currentSettings.companion.size
            )
        )) {
            apply(settings: settings)
        }
    }

    func setIgnoreMouse(_ ignore: Bool) {
        panel.ignoresMouseEvents = ignore || currentSettings.companion.locked
    }

    func resizeForAspect(aspectRatio: Double, topInset: Double, preferredPlacement: String?) -> String {
        currentImageAspectRatio = aspectRatio
        let resizeCenter = centerPoint(for: logicalBoundsAnchor ?? currentLogicalBounds())
        let visibleBounds = resizeCompanionPanel(
            center: resizeCenter,
            aspectRatio: aspectRatio,
            topInset: Int(topInset.rounded()),
            preservesCenter: true
        )
        persistBounds(logicalBoundsForCenter(resizeCenter, sizePixels: currentSettings.companion.sizePixels), normalize: false)

        if let preferredPlacement, preferredPlacement == "bottom" {
            return "bottom"
        }
        return CGFloat(visibleBounds.y) > CGFloat(topInset) + 24 ? "top" : "bottom"
    }

    func refreshImage() {
        let stats = try? usageService.currentStats(settings: currentSettings)
        refreshImage(todayTokens: stats?.totals.todayTokens ?? 0)
    }

    func refreshImage(todayTokens: Int) {
        latestTodayTokens = todayTokens
        let state = try? runtime.resolve(todayTokens: todayTokens, settings: currentSettings, action: interaction.currentAction)
        guard let state, let url = companionDisplayUrl(from: state) else {
            return
        }
        imageView.sd_setImage(with: url) { [weak self] image, _, _, _ in
            Task { @MainActor in
                self?.resizeForLoadedImage(image)
                self?.updateTokenBubblePosition()
            }
        }
    }

    private func resizeForLoadedImage(_ image: NSImage?) {
        guard let image, image.size.width > 0, image.size.height > 0 else {
            return
        }
        let aspectRatio = Double(image.size.width / image.size.height)
        currentImageAspectRatio = aspectRatio
        let resizeCenter = pendingSizeChangeCenter ?? centerPoint(for: logicalBoundsAnchor ?? currentLogicalBounds())
        resizeCompanionPanel(
            center: resizeCenter,
            aspectRatio: aspectRatio,
            preservesCenter: true
        )
        let visibleLogicalBounds = logicalBoundsForCenter(resizeCenter, sizePixels: currentSettings.companion.sizePixels)
        logicalBoundsAnchor = visibleLogicalBounds
        if currentSettings.companion.bounds != visibleLogicalBounds {
            persistBounds(visibleLogicalBounds, normalize: false)
        }
        pendingSizeChangeCenter = nil
        updateMousePassthrough(screenPoint: NSEvent.mouseLocation)
    }

    @discardableResult
    private func resizeCompanionPanel(
        center: ScreenPoint,
        aspectRatio: Double,
        topInset: Int = 0,
        preservesCenter: Bool = false
    ) -> Bounds {
        if preservesCenter {
            let safeImageHeight = max(1, currentSettings.companion.sizePixels)
            let safeAspectRatio = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 1
            let width = max(1, (Double(safeImageHeight) * safeAspectRatio).rounded())
            let height = max(1, Double(safeImageHeight + max(0, topInset)))
            let frame = NSRect(
                x: center.x - width / 2,
                y: center.y - height / 2,
                width: width,
                height: height
            )
            setPanelFrame(frame)
            return Bounds(
                x: Int(frame.origin.x.rounded()),
                y: Int(frame.origin.y.rounded()),
                width: Int(frame.width.rounded()),
                height: Int(frame.height.rounded())
            )
        }

        let requestedBounds = companionBoundsForAspect(
            center: center,
            imageHeight: currentSettings.companion.sizePixels,
            aspectRatio: aspectRatio,
            topInset: topInset
        )
        let visibleBounds = normalizeCompanionBoundsForScreens(requestedBounds)
        setPanelBounds(visibleBounds)
        return visibleBounds
    }

    private func setPanelBounds(_ bounds: Bounds) {
        setPanelFrame(NSRect(
            x: CGFloat(bounds.x),
            y: CGFloat(bounds.y),
            width: CGFloat(bounds.width),
            height: CGFloat(bounds.height)
        ))
    }

    private func setPanelFrame(_ frame: NSRect) {
        contentWidthConstraint?.constant = frame.width
        contentHeightConstraint?.constant = frame.height
        panel.setFrame(frame, display: true)
        contentView.setFrameSize(frame.size)
        contentView.layoutSubtreeIfNeeded()
        imageView.needsDisplay = true
    }

    private func currentLogicalBounds() -> Bounds {
        companionBoundsForAspect(
            center: panelCenter(),
            imageHeight: currentSettings.companion.sizePixels,
            aspectRatio: 1
        )
    }

    private func logicalBoundsForCenter(_ center: ScreenPoint, sizePixels: Int) -> Bounds {
        companionBoundsForAspect(
            center: center,
            imageHeight: sizePixels,
            aspectRatio: 1
        )
    }

    private func panelCenter() -> ScreenPoint {
        ScreenPoint(x: panel.frame.midX, y: panel.frame.midY)
    }

    private func centerPoint(for bounds: Bounds) -> ScreenPoint {
        ScreenPoint(
            x: Double(bounds.x) + Double(bounds.width) / 2,
            y: Double(bounds.y) + Double(bounds.height) / 2
        )
    }

    private func applyWindowLevel() {
        panel.isFloatingPanel = currentSettings.companion.alwaysOnTop
        panel.level = currentSettings.companion.alwaysOnTop ? .floating : .normal
    }

    private func applyWindowOrdering(previousAlwaysOnTop: Bool) {
        guard previousAlwaysOnTop != currentSettings.companion.alwaysOnTop else {
            return
        }

        if currentSettings.companion.alwaysOnTop {
            panel.orderFront(nil)
        } else {
            panel.orderBack(nil)
        }
    }

    private func startWindowOrderingMonitoring() {
        workspaceActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let activatedBundleIdentifier = (
                notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            )?.bundleIdentifier
            Task { @MainActor in
                self?.handleWorkspaceActivation(activatedBundleIdentifier: activatedBundleIdentifier)
            }
        }
    }

    private func handleWorkspaceActivation(activatedBundleIdentifier: String?) {
        guard !currentSettings.companion.alwaysOnTop else {
            return
        }
        guard activatedBundleIdentifier != Bundle.main.bundleIdentifier else {
            return
        }
        panel.orderBack(nil)
    }

    private func startScreenChangeMonitoring() {
        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleScreenParametersChanged()
            }
        }
    }

    private func handleScreenParametersChanged() {
        // Displays were connected/disconnected or a resolution changed. If the
        // companion now sits off every available screen, clamp it back onto a
        // visible work area and persist the corrected position.
        let currentBounds = Bounds(
            x: Int(panel.frame.origin.x.rounded()),
            y: Int(panel.frame.origin.y.rounded()),
            width: Int(panel.frame.width.rounded()),
            height: Int(panel.frame.height.rounded())
        )
        let workAreas = companionScreenWorkAreas()
        let isOffscreen = !companionBoundsIntersectAnyWorkArea(bounds: currentBounds, workAreas: workAreas)
        let normalizedBounds = normalizeCompanionBoundsForWorkAreas(
            bounds: currentBounds,
            workAreas: workAreas,
            margin: isOffscreen ? companionRecoveryMargin : 0
        )
        guard normalizedBounds != currentBounds else {
            return
        }
        setPanelBounds(normalizedBounds)
        let center = centerPoint(for: normalizedBounds)
        let visibleLogicalBounds = logicalBoundsForCenter(center, sizePixels: currentSettings.companion.sizePixels)
        logicalBoundsAnchor = visibleLogicalBounds
        persistBounds(visibleLogicalBounds, normalize: false)
        updateMousePassthrough(screenPoint: NSEvent.mouseLocation)
    }

    private func startDrag(point: ScreenPoint) {
        guard !currentSettings.companion.locked else {
            return
        }
        hideTokenBubble()
        dragState = CompanionDragState(
            startPoint: point,
            startBounds: Bounds(
                x: Int(panel.frame.origin.x),
                y: Int(panel.frame.origin.y),
                width: Int(panel.frame.width),
                height: Int(panel.frame.height)
            )
        )
    }

    private func movePanel(to point: ScreenPoint) {
        guard !currentSettings.companion.locked else {
            return
        }
        guard let dragState else {
            return
        }
        let bounds = companionBoundsDuringDrag(
            startBounds: dragState.startBounds,
            startPoint: dragState.startPoint,
            currentPoint: point
        )
        panel.setFrame(
            NSRect(
                x: CGFloat(bounds.x),
                y: CGFloat(bounds.y),
                width: CGFloat(bounds.width),
                height: CGFloat(bounds.height)
            ),
            display: true
        )
    }

    private func endDrag() {
        dragState = nil
    }

    private func persistBounds() {
        persistBounds(currentLogicalBounds())
    }

    private func persistBounds(_ bounds: Bounds, normalize: Bool = true) {
        let normalizedBounds = normalize ? normalizeCompanionBoundsForScreens(bounds) : bounds
        if let settings = try? settingsStore.update(TokeyPalSettingsUpdate(
            companion: CompanionSettings(
                bounds: normalizedBounds,
                locked: currentSettings.companion.locked,
                alwaysOnTop: currentSettings.companion.alwaysOnTop,
                size: currentSettings.companion.size
            )
        )) {
            currentSettings = settings
            logicalBoundsAnchor = normalizedBounds
        }
    }

    private func triggerCompanionAction(_ action: String) {
        guard interaction.trigger(action) != nil else {
            return
        }
        actionLoopObservation = nil
        let state = try? runtime.resolve(todayTokens: latestTodayTokens, settings: currentSettings, action: interaction.currentAction)
        guard let state, let url = companionDisplayUrl(from: state) else {
            return
        }
        imageView.sd_setImage(with: url) { [weak self] image, _, _, _ in
            Task { @MainActor in
                guard let self else {
                    return
                }
                self.resizeForLoadedImage(image)
                guard self.interaction.currentAction == action else {
                    return
                }
                self.observeActionLoop(for: action)
            }
        }
    }

    private func observeActionLoop(for action: String) {
        actionLoopObservation = imageView.observe(\.currentLoopCount, options: [.new]) { [weak self] _, change in
            guard (change.newValue ?? 0) > 0 else {
                return
            }
            Task { @MainActor in
                guard let self, self.interaction.currentAction == action, self.interaction.animationTimeout() != nil else {
                    return
                }
                self.actionLoopObservation = nil
                self.refreshImage(todayTokens: self.latestTodayTokens)
            }
        }
    }

    private func startIdleActionTimer() {
        idleActionTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.triggerCompanionAction("idle")
            }
        }
    }

    private func showTokenBubble() {
        guard dragState == nil else {
            return
        }
        bubbleLabel.stringValue = formatCompanionTokenBubble(latestTodayTokens)
        updateTokenBubblePosition()
        bubbleLabel.isHidden = false
    }

    private func hideTokenBubble() {
        bubbleLabel.isHidden = true
    }

    private func updateTokenBubblePosition() {
        contentView.layoutSubtreeIfNeeded()
        let fallbackTopConstant: CGFloat = 72
        guard let visibleBounds = imageView.visibleContentBounds() else {
            bubbleLabelTopConstraint?.constant = fallbackTopConstant
            return
        }

        let visibleFrame = imageView.convert(visibleBounds, to: contentView)
        let topConstant = companionBubbleTopAnchorConstant(
            visibleFrame: CompanionImageFrame(
                x: Double(visibleFrame.origin.x),
                y: Double(visibleFrame.origin.y),
                width: Double(visibleFrame.width),
                height: Double(visibleFrame.height)
            ),
            viewSize: CompanionImageSize(
                width: Double(contentView.bounds.width),
                height: Double(contentView.bounds.height)
            ),
            bubbleHeight: Double(bubbleLabel.bounds.height > 0 ? bubbleLabel.bounds.height : 44),
            gap: 30
        )
        bubbleLabelTopConstraint?.constant = CGFloat(topConstant)
    }

    private func handlePointerEntered() {
        guard !pointerIsOverCompanion else {
            return
        }
        pointerIsOverCompanion = true
        showTokenBubble()
        triggerCompanionAction("hover")
    }

    private func handlePointerExited() {
        guard pointerIsOverCompanion else {
            return
        }
        pointerIsOverCompanion = false
        hideTokenBubble()
    }

    private func startMousePassthroughMonitoring() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .mouseMoved,
            .leftMouseDragged,
            .rightMouseDragged
        ]) { [weak self] _ in
            let screenPoint = NSEvent.mouseLocation
            Task { @MainActor in
                self?.updateMousePassthrough(screenPoint: screenPoint)
            }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [
            .mouseMoved,
            .leftMouseDragged,
            .rightMouseDragged
        ]) { [weak self] event in
            let screenPoint = Self.screenPoint(for: event)
            Task { @MainActor in
                self?.updateMousePassthrough(screenPoint: screenPoint)
            }
            return event
        }
    }

    private func updateMousePassthrough(screenPoint: NSPoint) {
        let isOverCompanion: Bool
        let shouldIgnore: Bool
        if currentSettings.companion.locked {
            isOverCompanion = false
            shouldIgnore = true
        } else if dragState != nil {
            isOverCompanion = true
            shouldIgnore = false
        } else if panel.frame.contains(screenPoint) {
            let windowPoint = panel.convertPoint(fromScreen: screenPoint)
            isOverCompanion = imageView.capturesWindowPoint(windowPoint)
            shouldIgnore = !isOverCompanion
        } else {
            isOverCompanion = false
            shouldIgnore = false
        }

        if panel.ignoresMouseEvents != shouldIgnore {
            panel.ignoresMouseEvents = shouldIgnore
        }

        if isOverCompanion {
            handlePointerEntered()
        } else {
            handlePointerExited()
        }
    }

    private static func screenPoint(for event: NSEvent) -> NSPoint {
        if let window = event.window {
            return window.convertPoint(toScreen: event.locationInWindow)
        }
        return NSEvent.mouseLocation
    }
}

private struct CompanionDragState {
    var startPoint: ScreenPoint
    var startBounds: Bounds
}

final class CompanionContainerView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }
}

final class CompanionBubbleLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class CompanionBubbleCell: NSTextFieldCell {
    private let horizontalTextPadding: CGFloat = 24
    private let verticalTextPadding: CGFloat = 8

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let paddedRect = rect.insetBy(dx: horizontalTextPadding, dy: verticalTextPadding)
        let textSize = cellSize(forBounds: paddedRect)
        let verticalPadding = max(verticalTextPadding, (rect.height - textSize.height) / 2)
        return rect.insetBy(dx: horizontalTextPadding, dy: verticalPadding)
    }

    override func cellSize(forBounds rect: NSRect) -> NSSize {
        let textSize = super.cellSize(forBounds: rect)
        return NSSize(
            width: textSize.width + horizontalTextPadding * 2,
            height: textSize.height + verticalTextPadding * 2
        )
    }
}

private let companionRecoveryMargin = 32

@MainActor
private func companionScreenWorkAreas() -> [Bounds] {
    NSScreen.screens.map { screen in
        let visible = screen.visibleFrame
        return Bounds(
            x: Int(visible.origin.x),
            y: Int(visible.origin.y),
            width: Int(visible.width),
            height: Int(visible.height)
        )
    }
}

@MainActor
private func normalizeCompanionBoundsForScreens(_ bounds: Bounds, margin: Int = 0) -> Bounds {
    normalizeCompanionBoundsForWorkAreas(
        bounds: bounds,
        workAreas: companionScreenWorkAreas(),
        margin: margin
    )
}

@MainActor
final class CompanionImageView: SDAnimatedImageView {
    var isLocked = false
    var dragStarted: ((ScreenPoint) -> Void)?
    var dragMoved: ((ScreenPoint) -> Void)?
    var dragEnded: (() -> Void)?
    var pointerEntered: (() -> Void)?
    var pointerExited: (() -> Void)?
    var clicked: (() -> Void)?
    var contextMenuProvider: (() -> NSMenu)?
    private var isDragging = false
    private var didMoveDuringDrag = false
    private var trackingAreaReference: NSTrackingArea?
    private var alphaMask = CompanionAlphaMask()

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard super.hitTest(point) === self else {
            return nil
        }
        guard capturesViewPoint(point) else {
            return nil
        }
        return self
    }

    func capturesWindowPoint(_ windowPoint: NSPoint) -> Bool {
        capturesViewPoint(convert(windowPoint, from: nil))
    }

    func visibleContentBounds() -> NSRect? {
        alphaMask.visibleBounds(in: bounds, image: currentDisplayImage)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaReference = area
    }

    override func mouseEntered(with event: NSEvent) {
        guard !isLocked else {
            return
        }
        pointerEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        pointerExited?()
    }

    override func mouseDown(with event: NSEvent) {
        guard !isLocked else {
            return
        }
        isDragging = true
        didMoveDuringDrag = false
        dragStarted?(screenPoint(for: event))
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isLocked, isDragging else {
            return
        }
        didMoveDuringDrag = true
        dragMoved?(screenPoint(for: event))
    }

    override func mouseUp(with event: NSEvent) {
        guard !isLocked, isDragging else {
            return
        }
        isDragging = false
        if !didMoveDuringDrag {
            clicked?()
        }
        dragEnded?()
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = contextMenuProvider?() else {
            super.rightMouseDown(with: event)
            return
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    private func screenPoint(for event: NSEvent) -> ScreenPoint {
        let windowOrigin = window?.frame.origin ?? .zero
        return ScreenPoint(
            x: event.locationInWindow.x + windowOrigin.x,
            y: event.locationInWindow.y + windowOrigin.y
        )
    }

    private var currentDisplayImage: NSImage? {
        currentFrame ?? image
    }

    private func capturesViewPoint(_ point: NSPoint) -> Bool {
        guard bounds.contains(point) else {
            return false
        }
        return alphaMask.captures(point: point, in: bounds, image: currentDisplayImage)
    }
}

private struct CompanionAlphaMask {
    private var cgImage: CGImage?
    private var width = 0
    private var height = 0
    private var pixels: [UInt8] = []

    mutating func captures(point: NSPoint, in bounds: NSRect, image: NSImage?) -> Bool {
        guard let image, let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return false
        }
        if self.cgImage !== cgImage {
            rebuild(from: cgImage)
        }
        guard width > 0, height > 0 else {
            return false
        }
        let viewPoint = ScreenPoint(x: point.x, y: point.y)
        guard let pixel = companionImagePixelCoordinate(
            point: viewPoint,
            imageSize: CompanionImageSize(width: Double(width), height: Double(height)),
            viewSize: CompanionImageSize(width: Double(bounds.width), height: Double(bounds.height))
        ) else {
            return false
        }
        let alphaIndex = ((pixel.y * width) + pixel.x) * 4 + 3
        guard pixels.indices.contains(alphaIndex) else {
            return false
        }
        return companionImageAlphaCapturesMouse(pixels[alphaIndex])
    }

    mutating func visibleBounds(in bounds: NSRect, image: NSImage?) -> NSRect? {
        guard let image, let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        if self.cgImage !== cgImage {
            rebuild(from: cgImage)
        }
        guard let pixelBounds = companionImageVisiblePixelBounds(width: width, height: height, pixels: pixels),
              let visibleFrame = companionImageVisibleFrame(
                pixelBounds: pixelBounds,
                imageSize: CompanionImageSize(width: Double(width), height: Double(height)),
                viewSize: CompanionImageSize(width: Double(bounds.width), height: Double(bounds.height))
              ) else {
            return nil
        }
        return NSRect(
            x: visibleFrame.x,
            y: visibleFrame.y,
            width: visibleFrame.width,
            height: visibleFrame.height
        )
    }

    private mutating func rebuild(from cgImage: CGImage) {
        self.cgImage = cgImage
        width = cgImage.width
        height = cgImage.height
        var nextPixels = Array(repeating: UInt8(0), count: max(0, width * height * 4))
        guard width > 0, height > 0, !nextPixels.isEmpty else {
            pixels = []
            return
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        var didDraw = false
        nextPixels.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo
                  ) else {
                return
            }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            didDraw = true
        }
        if didDraw {
            pixels = nextPixels
        } else {
            pixels = []
            width = 0
            height = 0
        }
    }
}

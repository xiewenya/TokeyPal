import Testing
@testable import TokeyPalNative

@Test func companionBoundsStayInsideWorkArea() {
    let bounds = normalizeCompanionBounds(
        bounds: Bounds(x: -100, y: -100, width: 180, height: 180),
        workArea: Bounds(x: 0, y: 0, width: 1440, height: 900)
    )

    #expect(bounds == Bounds(x: 0, y: 0, width: 180, height: 180))
}

@Test func companionBoundsClampToLowerRightEdge() {
    let bounds = normalizeCompanionBounds(
        bounds: Bounds(x: 1400, y: 850, width: 180, height: 180),
        workArea: Bounds(x: 0, y: 0, width: 1440, height: 900)
    )

    #expect(bounds == Bounds(x: 1260, y: 720, width: 180, height: 180))
}

@Test func savedCompanionBoundsOutsideCurrentDisplayAreRecovered() {
    let bounds = normalizeCompanionBounds(
        bounds: Bounds(x: 1637, y: 2131, width: 360, height: 360),
        workArea: Bounds(x: 0, y: 0, width: 1710, height: 1107)
    )

    #expect(bounds == Bounds(x: 1350, y: 747, width: 360, height: 360))
}

@Test func offscreenCompanionBoundsRecoverToPrimaryWorkArea() {
    let bounds = normalizeCompanionBoundsForWorkAreas(
        bounds: Bounds(x: 1637, y: 2131, width: 360, height: 360),
        workAreas: [
            Bounds(x: 0, y: 0, width: 1710, height: 1074),
            Bounds(x: 1710, y: -93, width: 1920, height: 1200)
        ]
    )

    #expect(bounds == Bounds(x: 1350, y: 714, width: 360, height: 360))
}

@Test func companionBoundsRecoverWhenExternalDisplayDisconnected() {
    // Bounds were saved on a second monitor that is now unplugged, so only the
    // primary work area remains. The companion should clamp back onto it.
    let bounds = normalizeCompanionBoundsForWorkAreas(
        bounds: Bounds(x: 2400, y: 1500, width: 360, height: 360),
        workAreas: [
            Bounds(x: 0, y: 0, width: 1710, height: 1074)
        ]
    )

    #expect(bounds == Bounds(x: 1350, y: 714, width: 360, height: 360))
}

@Test func companionRecoveryKeepsMarginFromEdges() {
    // Off-screen bounds recovered with a margin should not sit flush against
    // the work-area edges.
    let margin = 32
    let bounds = normalizeCompanionBoundsForWorkAreas(
        bounds: Bounds(x: 2400, y: 1500, width: 240, height: 240),
        workAreas: [
            Bounds(x: 0, y: 0, width: 1728, height: 1084)
        ],
        margin: margin
    )

    #expect(bounds == Bounds(x: 1728 - 240 - margin, y: 1084 - 240 - margin, width: 240, height: 240))
}

@Test func companionRecoveryMarginDoesNotMoveOnscreenBounds() {
    // A position comfortably inside the work area must be left untouched even
    // when a margin is requested.
    let bounds = normalizeCompanionBoundsForWorkAreas(
        bounds: Bounds(x: 600, y: 400, width: 240, height: 240),
        workAreas: [
            Bounds(x: 0, y: 0, width: 1728, height: 1084)
        ],
        margin: 32
    )

    #expect(bounds == Bounds(x: 600, y: 400, width: 240, height: 240))
}

@Test func companionBoundsIntersectionDetectsOffscreen() {
    let workAreas = [Bounds(x: 0, y: 0, width: 1728, height: 1084)]

    #expect(companionBoundsIntersectAnyWorkArea(
        bounds: Bounds(x: 600, y: 400, width: 240, height: 240),
        workAreas: workAreas
    ) == true)
    #expect(companionBoundsIntersectAnyWorkArea(
        bounds: Bounds(x: 2400, y: 1500, width: 240, height: 240),
        workAreas: workAreas
    ) == false)
}

@Test func companionDragMovesByGlobalPointerDeltaFromStartingBounds() {
    let bounds = companionBoundsDuringDrag(
        startBounds: Bounds(x: 20, y: 40, width: 180, height: 180),
        startPoint: ScreenPoint(x: 100, y: 120),
        currentPoint: ScreenPoint(x: 115, y: 105)
    )

    #expect(bounds == Bounds(x: 35, y: 25, width: 180, height: 180))
}

@Test func companionAspectResizeKeepsTheCurrentWindowCenter() {
    let currentFrame = Bounds(x: 100, y: 200, width: 640, height: 360)
    let logicalBounds = companionLogicalBoundsForFrame(frame: currentFrame, sizePixels: 240)
    let resizedBounds = companionBoundsForAspect(
        center: ScreenPoint(
            x: Double(logicalBounds.x) + Double(logicalBounds.width) / 2,
            y: Double(logicalBounds.y) + Double(logicalBounds.height) / 2
        ),
        imageHeight: 360,
        aspectRatio: 16.0 / 9.0
    )

    #expect(logicalBounds == Bounds(x: 300, y: 260, width: 240, height: 240))
    #expect(resizedBounds == Bounds(x: 100, y: 200, width: 640, height: 360))
}

@Test func companionImageHitTestIgnoresLetterboxedViewArea() {
    let pixel = companionImagePixelCoordinate(
        point: ScreenPoint(x: 50, y: 10),
        imageSize: CompanionImageSize(width: 100, height: 50),
        viewSize: CompanionImageSize(width: 100, height: 100)
    )

    #expect(pixel == nil)
}

@Test func companionImageHitTestMapsAspectFitPointToImagePixel() {
    let pixel = companionImagePixelCoordinate(
        point: ScreenPoint(x: 50, y: 50),
        imageSize: CompanionImageSize(width: 100, height: 50),
        viewSize: CompanionImageSize(width: 100, height: 100)
    )

    #expect(pixel == CompanionImagePixel(x: 50, y: 25))
}

@Test func companionImageAlphaThresholdControlsMouseCapture() {
    #expect(companionImageAlphaCapturesMouse(0) == false)
    #expect(companionImageAlphaCapturesMouse(9) == false)
    #expect(companionImageAlphaCapturesMouse(10) == true)
    #expect(companionImageAlphaCapturesMouse(255) == true)
}

@Test func companionImageVisiblePixelBoundsUseNonTransparentAlpha() {
    var pixels = Array(repeating: UInt8(0), count: 4 * 4 * 4)
    pixels[((1 * 4) + 2) * 4 + 3] = 10
    pixels[((3 * 4) + 1) * 4 + 3] = 255

    let bounds = companionImageVisiblePixelBounds(width: 4, height: 4, pixels: pixels)

    #expect(bounds == CompanionImagePixelBounds(minX: 1, minY: 1, maxX: 2, maxY: 3))
}

@Test func companionImageVisibleFrameMapsPixelBoundsIntoAspectFitView() {
    let frame = companionImageVisibleFrame(
        pixelBounds: CompanionImagePixelBounds(minX: 0, minY: 1, maxX: 3, maxY: 2),
        imageSize: CompanionImageSize(width: 4, height: 4),
        viewSize: CompanionImageSize(width: 8, height: 8)
    )

    #expect(frame == CompanionImageFrame(x: 0, y: 2, width: 8, height: 4))
}

@Test func companionBubbleTopAnchorUsesThirtyPointGapFromVisibleImage() {
    let topPlacement = companionBubbleTopAnchorConstant(
        visibleFrame: CompanionImageFrame(x: 0, y: 40, width: 180, height: 100),
        viewSize: CompanionImageSize(width: 180, height: 220),
        bubbleHeight: 44,
        gap: 30
    )

    let bottomPlacement = companionBubbleTopAnchorConstant(
        visibleFrame: CompanionImageFrame(x: 0, y: 100, width: 180, height: 100),
        viewSize: CompanionImageSize(width: 180, height: 220),
        bubbleHeight: 44,
        gap: 30
    )

    #expect(topPlacement == 6)
    #expect(bottomPlacement == 150)
}

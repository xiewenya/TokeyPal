import Foundation

public struct ScreenPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct CompanionImageSize: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct CompanionImagePixel: Equatable, Sendable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

public struct CompanionImagePixelBounds: Equatable, Sendable {
    public var minX: Int
    public var minY: Int
    public var maxX: Int
    public var maxY: Int

    public init(minX: Int, minY: Int, maxX: Int, maxY: Int) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }
}

public struct CompanionImageFrame: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public func companionImagePixelCoordinate(
    point: ScreenPoint,
    imageSize: CompanionImageSize,
    viewSize: CompanionImageSize
) -> CompanionImagePixel? {
    guard imageSize.width > 0, imageSize.height > 0, viewSize.width > 0, viewSize.height > 0 else {
        return nil
    }

    let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
    let drawnWidth = imageSize.width * scale
    let drawnHeight = imageSize.height * scale
    let drawnX = (viewSize.width - drawnWidth) / 2
    let drawnY = (viewSize.height - drawnHeight) / 2

    guard point.x >= drawnX, point.x < drawnX + drawnWidth,
          point.y >= drawnY, point.y < drawnY + drawnHeight else {
        return nil
    }

    let imageX = ((point.x - drawnX) / scale).rounded(.down)
    let imageY = ((point.y - drawnY) / scale).rounded(.down)
    let clampedX = clamp(Int(imageX), min: 0, max: max(0, Int(imageSize.width) - 1))
    let clampedY = clamp(Int(imageY), min: 0, max: max(0, Int(imageSize.height) - 1))
    return CompanionImagePixel(x: clampedX, y: clampedY)
}

public func companionImageAlphaCapturesMouse(_ alpha: UInt8) -> Bool {
    alpha >= 10
}

public func companionBoundsForAspect(
    center: ScreenPoint,
    imageHeight: Int,
    aspectRatio: Double,
    topInset: Int = 0
) -> Bounds {
    let safeImageHeight = max(1, imageHeight)
    let safeAspectRatio = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 1
    let width = max(1, Int((Double(safeImageHeight) * safeAspectRatio).rounded()))
    let height = max(1, safeImageHeight + max(0, topInset))

    return Bounds(
        x: Int((center.x - Double(width) / 2).rounded()),
        y: Int((center.y - Double(height) / 2).rounded()),
        width: width,
        height: height
    )
}

public func companionLogicalBoundsForFrame(frame: Bounds, sizePixels: Int) -> Bounds {
    let safeSize = max(1, sizePixels)
    let center = ScreenPoint(
        x: Double(frame.x) + Double(frame.width) / 2,
        y: Double(frame.y) + Double(frame.height) / 2
    )
    return companionBoundsForAspect(center: center, imageHeight: safeSize, aspectRatio: 1)
}

public func companionImageVisiblePixelBounds(width: Int, height: Int, pixels: [UInt8]) -> CompanionImagePixelBounds? {
    guard width > 0, height > 0, pixels.count >= width * height * 4 else {
        return nil
    }

    var minX = width
    var minY = height
    var maxX = -1
    var maxY = -1

    for y in 0..<height {
        for x in 0..<width {
            let alphaIndex = ((y * width) + x) * 4 + 3
            guard pixels.indices.contains(alphaIndex) else {
                continue
            }
            guard companionImageAlphaCapturesMouse(pixels[alphaIndex]) else {
                continue
            }
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
    }

    guard maxX >= minX, maxY >= minY else {
        return nil
    }
    return CompanionImagePixelBounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
}

public func companionImageVisibleFrame(
    pixelBounds: CompanionImagePixelBounds,
    imageSize: CompanionImageSize,
    viewSize: CompanionImageSize
) -> CompanionImageFrame? {
    guard imageSize.width > 0, imageSize.height > 0, viewSize.width > 0, viewSize.height > 0 else {
        return nil
    }

    let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
    let drawnWidth = imageSize.width * scale
    let drawnHeight = imageSize.height * scale
    let drawnX = (viewSize.width - drawnWidth) / 2
    let drawnY = (viewSize.height - drawnHeight) / 2
    let visibleWidth = Double(pixelBounds.maxX - pixelBounds.minX + 1) * scale
    let visibleHeight = Double(pixelBounds.maxY - pixelBounds.minY + 1) * scale

    return CompanionImageFrame(
        x: drawnX + Double(pixelBounds.minX) * scale,
        y: drawnY + Double(pixelBounds.minY) * scale,
        width: visibleWidth,
        height: visibleHeight
    )
}

public func companionBubbleTopAnchorConstant(
    visibleFrame: CompanionImageFrame,
    viewSize: CompanionImageSize,
    bubbleHeight: Double,
    gap: Double
) -> Double {
    guard viewSize.height > 0, bubbleHeight > 0 else {
        return 0
    }

    let maxConstant = max(0, viewSize.height - bubbleHeight)
    func clampedTopConstant(_ value: Double) -> Double {
        min(max(value, 0), maxConstant)
    }

    let visibleTop = visibleFrame.y + visibleFrame.height
    let aboveTopY = visibleTop + gap + bubbleHeight
    if aboveTopY <= viewSize.height {
        return clampedTopConstant(viewSize.height - aboveTopY)
    }

    let belowTopY = visibleFrame.y - gap
    if belowTopY - bubbleHeight >= 0 {
        return clampedTopConstant(viewSize.height - belowTopY)
    }

    let spaceAbove = viewSize.height - visibleTop
    let spaceBelow = visibleFrame.y
    let preferredTopY = spaceAbove >= spaceBelow ? aboveTopY : belowTopY
    return clampedTopConstant(viewSize.height - preferredTopY)
}

public func normalizeCompanionBounds(bounds: Bounds, workArea: Bounds, margin: Int = 0) -> Bounds {
    let width = bounds.width
    let height = bounds.height
    // Clamp the requested margin so it never collapses the available range when
    // the companion nearly fills the work area.
    let safeMargin = max(0, margin)
    let marginX = min(safeMargin, max(0, (workArea.width - width) / 2))
    let marginY = min(safeMargin, max(0, (workArea.height - height) / 2))
    let minX = workArea.x + marginX
    let minY = workArea.y + marginY
    let maxX = workArea.x + workArea.width - width - marginX
    let maxY = workArea.y + workArea.height - height - marginY

    return Bounds(
        x: clamp(bounds.x, min: minX, max: max(minX, maxX)),
        y: clamp(bounds.y, min: minY, max: max(minY, maxY)),
        width: width,
        height: height
    )
}

public func normalizeCompanionBoundsForWorkAreas(bounds: Bounds, workAreas: [Bounds], margin: Int = 0) -> Bounds {
    guard !workAreas.isEmpty else {
        return bounds
    }

    let matching = workAreas.first { workArea in
        intersects(bounds, workArea)
    } ?? workAreas[0]

    return normalizeCompanionBounds(bounds: bounds, workArea: matching, margin: margin)
}

public func companionBoundsIntersectAnyWorkArea(bounds: Bounds, workAreas: [Bounds]) -> Bool {
    workAreas.contains { intersects(bounds, $0) }
}

public func companionBoundsDuringDrag(startBounds: Bounds, startPoint: ScreenPoint, currentPoint: ScreenPoint) -> Bounds {
    Bounds(
        x: startBounds.x + Int((currentPoint.x - startPoint.x).rounded()),
        y: startBounds.y + Int((currentPoint.y - startPoint.y).rounded()),
        width: startBounds.width,
        height: startBounds.height
    )
}

private func intersects(_ left: Bounds, _ right: Bounds) -> Bool {
    let leftMaxX = left.x + left.width
    let leftMaxY = left.y + left.height
    let rightMaxX = right.x + right.width
    let rightMaxY = right.y + right.height

    return left.x < rightMaxX &&
        leftMaxX > right.x &&
        left.y < rightMaxY &&
        leftMaxY > right.y
}

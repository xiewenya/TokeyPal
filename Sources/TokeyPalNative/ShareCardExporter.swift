import AppKit
import Foundation

public struct ShareExportResult: Codable, Equatable, Sendable {
    public var filePath: String
}

public struct ShareCardExporter: Sendable {
    public init() {}

    public func export(input: ShareCardInput, outputURL: URL? = nil) throws -> ShareExportResult {
        let outputURL = outputURL ?? defaultOutputURL(localDate: input.localDate)
        let image = drawShareCard(input)
        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            throw ShareCardExporterError.renderFailed
        }

        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try png.write(to: outputURL, options: .atomic)
        return ShareExportResult(filePath: outputURL.path)
    }

    private func defaultOutputURL(localDate: String) -> URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
        return downloads.appendingPathComponent("TokeyPal-\(localDate).png")
    }
}

public enum ShareCardExporterError: Error, Equatable {
    case renderFailed
}

private func drawShareCard(_ card: ShareCardInput) -> NSImage {
    let size = NSSize(width: 900, height: 1200)
    let image = NSImage(size: size)
    image.lockFocus()
    defer { image.unlockFocus() }

    let rect = NSRect(origin: .zero, size: size)
    NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.15, alpha: 1).setFill()
    rect.fill()

    drawVerticalGradient(
        in: rect,
        colors: [
            NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.15, alpha: 1),
            NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.24, alpha: 1),
            NSColor(calibratedRed: 0.06, green: 0.46, blue: 0.43, alpha: 1)
        ]
    )

    drawText("Today Total Usage", at: NSPoint(x: 76, y: 1092), fontSize: 28, weight: .bold, color: mint)
    drawText("\(card.progressTokens.formatted(.number.locale(Locale(identifier: "en_US")))) tokens", at: NSPoint(x: 76, y: 986), fontSize: 74, weight: .heavy, color: .white)
    drawText(card.localDate, at: NSPoint(x: 76, y: 930), fontSize: 28, weight: .bold, color: mint)
    drawText(card.stageLabel, at: NSPoint(x: 76, y: 880), fontSize: 34, weight: .regular, color: pale)

    var breakdownY = 820
    if card.todayUsage.count > 1 {
        for usage in card.todayUsage.prefix(6) {
            drawText(usage.label, at: NSPoint(x: 76, y: CGFloat(breakdownY)), fontSize: 24, weight: .regular, color: lightMint)
            drawText(
                "\(usage.tokens.formatted(.number.locale(Locale(identifier: "en_US")))) tokens",
                at: NSPoint(x: 390, y: CGFloat(breakdownY)),
                fontSize: 24,
                weight: .bold,
                color: .white
            )
            breakdownY -= 38
        }
    }

    if card.approximate {
        drawPill("Includes estimated data", at: NSPoint(x: 76, y: CGFloat(breakdownY - 20)))
    }

    if card.includeCharacter, let characterImage = card.characterImage, let url = URL(string: characterImage), let character = NSImage(contentsOf: url) {
        character.draw(in: NSRect(x: 468, y: 64, width: 360, height: 360), from: .zero, operation: .sourceOver, fraction: 1)
    }

    let sources = card.sources.isEmpty ? "No data sources" : card.sources.joined(separator: " / ")
    drawText(sources, at: NSPoint(x: 76, y: 76), fontSize: 24, weight: .regular, color: pale)
    return image
}

private let mint = NSColor(calibratedRed: 0.60, green: 0.96, blue: 0.89, alpha: 1)
private let pale = NSColor(calibratedRed: 0.80, green: 0.84, blue: 0.88, alpha: 1)
private let lightMint = NSColor(calibratedRed: 0.82, green: 0.98, blue: 0.90, alpha: 1)

private func drawText(_ text: String, at point: NSPoint, fontSize: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
        .foregroundColor: color
    ]
    text.draw(at: point, withAttributes: attributes)
}

private func drawPill(_ text: String, at point: NSPoint) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 22, weight: .bold),
        .foregroundColor: NSColor(calibratedRed: 0.73, green: 0.90, blue: 0.99, alpha: 1)
    ]
    let textSize = text.size(withAttributes: attributes)
    let rect = NSRect(x: point.x, y: point.y, width: textSize.width + 32, height: 42)
    NSColor(calibratedRed: 0.05, green: 0.45, blue: 0.65, alpha: 0.24).setFill()
    NSBezierPath(roundedRect: rect, xRadius: 21, yRadius: 21).fill()
    text.draw(at: NSPoint(x: point.x + 16, y: point.y + 9), withAttributes: attributes)
}

private func drawVerticalGradient(in rect: NSRect, colors: [NSColor]) {
    guard let gradient = NSGradient(colors: colors) else {
        return
    }
    gradient.draw(in: rect, angle: -45)
}
